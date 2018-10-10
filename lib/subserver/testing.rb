module Subserver
  class Testing

    def self.fake!
      Subserver::Pubsub.client = Subserver::Testing::Pubsub.new
    end

  end
end