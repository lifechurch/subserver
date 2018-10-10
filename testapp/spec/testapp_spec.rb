require 'spec_helper'

RSpec.describe Subserver::Testing do

  it 'mocks a Pubsub client' do
    pubsub_topic = Subserver::Pubsub.client.topic
    expect(pubsub_topic.publish).to eql(true)
  end

end