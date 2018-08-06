class TestSubscriber
  include Subserver::Subscriber
  subserver_options subscription: 'subserver-test'

  def perform(message)
    Rails.logger.info(message.data)
    message.acknowledge!
  end
end