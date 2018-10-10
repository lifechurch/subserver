require 'spec_helper'

RSpec.describe Subserver::Testing do

  it 'mocks a Pubsub client' do
    data = {name: 'test', id: 1}
    pubsub_topic = Subserver::Pubsub.client.topic "test_topic"
    expect(pubsub_topic.publish data.to_json).to eql(true)
  end

end