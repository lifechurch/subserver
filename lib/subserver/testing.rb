require 'subserver/testing/pubsub'

module Subserver
  module Testing

    def self.fake!
      Subserver::Pubsub.client = Subserver::Testing::Pubsub.new
    end

  end
end