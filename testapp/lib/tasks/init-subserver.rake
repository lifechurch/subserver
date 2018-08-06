namespace :subserver do
  desc 'Initalize Topic and Subscriver for Emulator'
  task init: :environment do
    # Load Client
    client = Subserver::Pubsub.client

    # Create Topic
    topic = client.create_topic "subserver-test"

    # Create Subscription
    subscription = topic.subscribe "subserver-test"
  end
end