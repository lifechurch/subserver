# frozen_string_literal: true

class FailingAutoSubscribingSubscriber
  include Subserver::Subscriber
  subserver_options subscription: 'your-gcloud-subscription-name'

  def self.auto_subscribe
    false
  end
end
