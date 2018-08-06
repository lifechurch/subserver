# frozen_string_literal: true
require 'socket'
require 'securerandom'
require 'subserver/exception_handler'

module Subserver
  ##
  # This module is part of Subserver core and not intended for extensions.
  #
  module Util
    include ExceptionHandler

    EXPIRY = 60 * 60 * 24

    def watchdog(last_words)
      yield
    rescue Exception => ex
      handle_exception(ex, { context: last_words })
      raise ex
    end

    def safe_thread(name, &block)
      Thread.new do
        Thread.current['subserver_label'] = name
        watchdog(name, &block)
      end
    end

    def logger
      Subserver.logger
    end

    def hostname
      ENV['DYNO'] || Socket.gethostname
    end

    def process_nonce
      @@process_nonce ||= SecureRandom.hex(6)
    end

    def identity
      @@identity ||= "#{hostname}:#{$$}:#{process_nonce}"
    end

    def fire_event(event, options={})
      reverse = options[:reverse]
      reraise = options[:reraise]

      arr = Subserver.options[:lifecycle_events][event]
      arr.reverse! if reverse
      arr.each do |block|
        begin
          block.call
        rescue => ex
          handle_exception(ex, { context: "Exception during Subserver lifecycle event.", event: event })
          raise ex if reraise
        end
      end
      arr.clear
    end
  end
end