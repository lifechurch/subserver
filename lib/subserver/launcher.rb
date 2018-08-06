# frozen_string_literal: true
require 'subserver/manager'

module Subserver
  # The Launcher is a very simple Actor whose job is to
  # start, monitor and stop the core Actors in Subserver.
  # If any of these actors die, the Subserver process exits
  # immediately.
  class Launcher
    include Util

    attr_accessor :manager

    def initialize(options)
      @manager = Subserver::Manager.new(options)
      @done = false
      @options = options
    end

    def run
      @manager.start
    end

    # Stops this instance from processing any more jobs,
    #
    def quiet
      @done = true
      @manager.quiet
    end

    # Shuts down the process.  This method does not
    # return until all work is complete and cleaned up.
    # It can take up to the timeout to complete.
    def stop
      deadline = Time.now + @options[:timeout]

      @done = true
      @manager.quiet
      @manager.stop(deadline)
    end

    def stopping?
      @done
    end

    private unless $TESTING

    def to_data
      @data ||= begin
        {
          'hostname' => hostname,
          'started_at' => Time.now.to_f,
          'pid' => $$,
          'tag' => @options[:tag] || '',
          'queues' => @options[:queues].uniq,
          'labels' => @options[:labels],
          'identity' => identity,
        }
      end
    end

    def to_json
      @json ||= begin
        # this data changes infrequently so dump it to a string
        # now so we don't need to dump it every heartbeat.
        Subserver.dump_json(to_data)
      end
    end

  end
end