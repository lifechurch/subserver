# frozen_string_literal: true

class AutoSubscribingSubscriber
  include Subserver::Subscriber
  subserver_options subscription: 'your-gcloud-subscription-name'

  def perform(message)
    # do something with message
    message.acknowledge!
  end

  def self.auto_subscribe
    true
  end
end
