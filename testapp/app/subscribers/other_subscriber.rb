class OtherSubscriber
  include Subserver::Subscriber
  subserver_options subscription: 'subserver-other'

  def perform(message)
    Rails.logger.info(message.data)
    message.acknowledge!
  end
end