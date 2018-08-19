namespace :subserver do
  desc 'Initalize Topic and Subscriver for Emulator'
  task init: :environment do
    # Load Client
    client = Subserver::Pubsub.client

    # Create Topics
    if client.topic("subserver-test").nil?
      topic = client.create_topic "subserver-test"
      # Create Subscription
      subscription = topic.subscribe "subserver-test"
    end

    if client.topic("subserver-other").nil?
      topic = client.create_topic "subserver-other"
      # Create Subscription
      subscription = topic.subscribe "subserver-other"
    end
  end
end