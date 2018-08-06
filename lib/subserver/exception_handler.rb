# frozen_string_literal: true
require 'subserver'

module Subserver
  module ExceptionHandler

    class Logger
      def call(ex, ctxHash)
        Subserver.logger.warn(Subserver.dump_json(ctxHash)) if !ctxHash.empty?
        Subserver.logger.warn("#{ex.class.name}: #{ex.message}")
        Subserver.logger.warn(ex.backtrace.join("\n")) unless ex.backtrace.nil?
      end

      Subserver.error_handlers << Subserver::ExceptionHandler::Logger.new
    end

    def handle_exception(ex, ctxHash={})
      Subserver.error_handlers.each do |handler|
        begin
          handler.call(ex, ctxHash)
        rescue => ex
          Subserver.logger.error "!!! ERROR HANDLER THREW AN ERROR !!!"
          Subserver.logger.error ex
          Subserver.logger.error ex.backtrace.join("\n") unless ex.backtrace.nil?
        end
      end
    end
  end
end