# frozen_string_literal: true
require 'subserver/util'
require 'subserver/message_logger'
require 'subserver/pubsub'
require 'thread'

module Subserver
  ##
  # The Listener is a standalone thread which:
  #
  # 1. Starts Google Pubsub subscription threads which: 
  #   a. Instantiate the Subscription class
  #   b. Run the middleware chain
  #   c. call subscriber #perform
  #
  # A Listener can exit due to shutdown (listner_stopped)
  # or due to an error during message processing (listener_died)
  #
  # If an error occurs during message processing, the
  # Listener calls the Manager to create a new one
  # to replace itself and exits.
  #
  class Listener

    include Util

    attr_reader :thread
    attr_reader :subscriber

    def initialize(mgr, subscriber)
      @mgr = mgr
      @down = false
      @done = false
      @thread = nil
      @reloader = Subserver.options[:reloader]
      @subscriber = subscriber
      @subscription = retrive_subscrption
      @logging = (mgr.options[:message_logger] || Subserver::MessageLogger).new
    end

    def name
      @subscriber.name
    end

    def stop
      @done = true
      return if !@thread
      
      # Stop the listener and wait for current messages to finish processing.
      @pubsub_listener.stop.wait!
      @mgr.listener_stopped(self)
    end

    def kill
      @done = true
      return if !@thread
      # Hard stop the listener and shutdown thread after timeout passes.
      @pubsub_listener.stop
      @thread.raise ::Subserver::Shutdown
    end

    def start
      @thread ||= safe_thread("listener", &method(:run))
    end

    private unless $TESTING

    def retrive_subscrption
      subscription_name = @subscriber.get_subserver_options[:subscription]
      begin
        subscription = Pubsub.client.subscription subscription_name
      rescue Google::Cloud::Error => e
        raise ArgumentError, "Invalid Subscription name: #{subscription_name} Please ensure your Pubsub subscription exists."
      end
      subscription
    end

    def connect_subscriber
      options = @subscriber.get_subserver_options
      logger.debug("Connecting to subscription with options: #{options}")
      @pubsub_listener = @subscription.listen streams: options[:streams], threads: options[:threads] do |received_message|
        logger.debug("Message Received: #{received_message}")
        process_message(received_message)
      end
    end

    def run
      begin
        connect_subscriber
        @pubsub_listener.start
      rescue Subserver::Shutdown
        @mgr.listener_stopped(self)
      rescue Exception => ex
        @mgr.listener_died(self, @subscriber, ex)
      end
    end

    def process_message(received_message)
      begin
        logger.debug("Executing Middleware")
        Subserver.middleware.invoke(@subscriber, received_message) do
          execute_processor(@subscriber, received_message)
        end
      rescue Subserver::Shutdown
        # Reject message if shutdown
        received_message.reject!
      rescue Exception => ex
        handle_exception(e, { context: "Exception raised during message processing.", message: received_message })
        raise e
      end
    end

    def execute_processor(subscriber, received_message)
      subscriber.new.perform(received_message)
    end

    # Ruby doesn't provide atomic counters out of the box so we'll
    # implement something simple ourselves.
    # https://bugs.ruby-lang.org/issues/14706
    class Counter
      def initialize
        @value = 0
        @lock = Mutex.new
      end

      def incr(amount=1)
        @lock.synchronize { @value = @value + amount }
      end

      def reset
        @lock.synchronize { val = @value; @value = 0; val }
      end
    end

    PROCESSED = Counter.new
    FAILURE = Counter.new
    # This is mutable global state but because each thread is storing
    # its own unique key/value, there's no thread-safety issue AFAIK.
    WORKER_STATE = {}

    def stats(job_hash, queue)
      tid = Subserver::Logging.tid
      WORKER_STATE[tid] = {:queue => queue, :payload => job_hash, :run_at => Time.now.to_i }

      begin
        yield
      rescue Exception
        FAILURE.incr
        raise
      ensure
        WORKER_STATE.delete(tid)
        PROCESSED.incr
      end
    end

  end
end