require 'subserver/subscriber'

class TestSubscriber
  include Subserver::Subscriber 
  subserver_options subscription: 'test', streams: 10

  def perform(message)
    logger.info(message)

    message.acknowledge!
  end
end