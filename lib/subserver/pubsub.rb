require "google/cloud/pubsub"

module Subserver
  module Pubsub
    def self.client
      defined?(@client) ? @client : initialize_client
    end

    def self.client=(client)
      @client = client
    end

    def self.initialize_client
      @client = Google::Cloud::Pubsub.new(
        project_id: options[:project_id] || ENV['PUBSUB_PROJECT_ID'],
        credentials: ( File.expand_path(options[:credentials]) if options[:credentials] )
      )
    end

    def self.options
      Subserver.options
    end
  end
end 

