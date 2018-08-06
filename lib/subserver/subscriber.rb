module Subserver
  module Subscriber

    def self.included(base)
      base.extend(ClassMethods)
    end

    def logger
      Subserver.logger
    end

    module ClassMethods
      @subserver_options

      def subserver_options(opts={})
        (@subserver_options ||= Subserver.default_subscriber_options).merge!(opts)
      end

      def get_subserver_options
        @subserver_options
      end 
    end

  end
end