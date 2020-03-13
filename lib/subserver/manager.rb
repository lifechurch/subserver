# frozen_string_literal: true
require 'subserver/util'
require 'subserver/listener'
require 'thread'
require 'set'

module Subserver

  ##
  # The Manager is the central coordination point in Subserver, controlling
  # the lifecycle of the Google Cloud Listeners.
  #
  # Tasks:
  #
  # 1. start: Load subscibers and start listeners.
  # 2. listener_died: restart listener
  # 3. quiet: tell listeners to stop listening and finish processing messages then shutdown.
  # 4. stop: hard stop the listeners by deadline.
  #
  # Note that only the last task requires its own Thread since it has to monitor
  # the shutdown process.  The other tasks are performed by other threads.
  #
  class Manager
    include Util

    attr_reader :listeners
    attr_reader :options
    attr_reader :subscribers

    def initialize(options={})
      logger.debug { options.inspect }
      @options = options
      
      @done = false
      @listeners = Set.new

      subscribers.each do |subscriber|
        next if subscriber.auto_subscribe? && !subscriber.auto_subscribe
        @listeners << Listener.new(self, subscriber)
      end

      @listeners.select!{ |l| l.valid? }

      @plock = Mutex.new
    end

    def start
      if @listeners.count > 0
        logger.info("Starting Listeners For: #{@listeners.map(&:name).join(', ')}")
        @listeners.each do |x|
          x.start
        end
      else
        logger.warn("No Listeners starting: Couldn't find any subscribers.")
      end
    end

    def quiet
      return if @done
      @done = true

      logger.info { "Stopping listeners" }
      @listeners.each { |x| x.stop }
      fire_event(:quiet, reverse: true)
    end

    # hack for quicker development / testing environment
    PAUSE_TIME = STDOUT.tty? ? 0.1 : 0.5

    def stop(deadline)
      quiet
      fire_event(:shutdown, reverse: true)

      # some of the shutdown events can be async,
      # we don't have any way to know when they're done but
      # give them a little time to take effect
      sleep PAUSE_TIME
      return if @listeners.empty?

      logger.info { "Pausing to allow listeners to finish..." }
      remaining = deadline - Time.now
      while remaining > PAUSE_TIME
        return if @listeners.empty?
        sleep PAUSE_TIME
        remaining = deadline - Time.now
      end
      return if @listeners.empty?

      hard_shutdown
    end

    def listener_stopped(listener)
      @plock.synchronize do
        @listeners.delete(listener)
      end
    end

    def listener_died(listener, subscriber, reason)
      logger.warn("Listener for #{subscriber.name} Died at #{Time.now}: #{reason}")
      # @plock.synchronize do
      #   @listeners.delete(listener)
      #   unless @done
      #     l = Listener.new(self, subscriber)
      #     @listeners << l
      #     l.start
      #   end
      # end
    end

    def stopped?
      @done
    end

    def subscribers
      @subscribers ||= load_subscribers
    end

    private

    def hard_shutdown
      # We've reached the timeout and we still have busy listeners.
      # They must die but their jobs shall live on.
      cleanup = nil
      @plock.synchronize do
        cleanup = @listeners.dup
      end

      if cleanup.size > 0
        logger.warn { "Killing #{cleanup.size} busy worker threads" }
        # Any message not aknowleged will be avalible for reprocessing
      end

      cleanup.each do |listener|
        listener.kill
      end
    end

    def load_subscribers
      # Expand Subscriber Directory from relative require 
      path = File.expand_path("#{options[:subscriber_dir]}/*.rb")

      # Require all subscriber files
      Dir[path].each { |f| require f } 

      # Create set of all classes including those in require loop
      classes = ObjectSpace.each_object(Class).to_a

      # Only included named classes that have included the Subscriber module
      subscribers = classes.select do |klass|
        klass.name && klass < ::Subserver::Subscriber && options[:queues].include?(klass.subserver_options[:queue])
      end
    end

  end
end