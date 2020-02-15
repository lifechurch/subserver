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
      @valid = true
      @done = false
      @thread = nil
      @reloader = Subserver.options[:reloader]
      @subscriber = subscriber
      @subscription = retrieve_subscription
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

    def valid?
      @valid
    end

    private unless $TESTING

    def retrieve_subscription
      subscription_name = @subscriber.get_subserver_options[:subscription]
      subscription = Pubsub.client.subscription subscription_name rescue nil
      if subscription.nil?
        logger.error "ArgumentError: Invalid Subscription name: #{subscription_name} in subscriber #{@subscriber.name}. Please ensure your Pubsub subscription exists."
        @valid = false
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
        # This begins the listener process in a forked thread
        fire_event(:listener_startup, reverse: false, reraise: true)
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
        @reloader.call do
          Subserver.middleware.invoke(@subscriber, received_message) do
            execute(@subscriber, received_message)
          end
        end
      rescue Subserver::Shutdown
        # Reject message if shutdown
        received_message.reject!
      rescue StandardError => error
        handle_exception error, {
          context: 'Exception raised during message processing.',
          message: received_message
        }
        raise
      end
    end

    def execute(subscriber, received_message)
      subscriber.new.perform(received_message)
    end

  end
end
