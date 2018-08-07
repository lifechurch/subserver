require 'subserver/subscriber'

class TestSubscriber
  include Subserver::Subscriber 
  subserver_options subscription: 'test'

  def perform(message)
    logger.info(message)

    message.acknowledge!
  end
end