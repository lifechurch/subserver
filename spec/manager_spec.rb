require 'spec_helper'
require_relative '../lib/subserver/manager'
require_relative '../lib/subserver/listener'
require_relative '../lib/subserver/subscriber'
require_relative 'fixtures/files/example_subscribers/auto_subscribing_subscriber'
require_relative 'fixtures/files/example_subscribers/failing_auto_subscribing_subscriber'

RSpec.describe Subserver::Manager do
  let(:example_options) { { queues: %w[default] } }

  subject { described_class.new example_options }

  describe 'initialization' do
    context 'when a subscriber class implements .auto_subscribe' do
      before do
        allow(Subserver::Pubsub).to receive(:client).and_return(
          double("book", subscription: 'subscription')
        )
      end

      it 'calls .auto_subscribe before adding to the listeners list' do
        expect(AutoSubscribingSubscriber).to receive :auto_subscribe
        subject
      end

      context 'when it succeeds in subscribing' do
        it 'makes it into the listeners list' do
          expect(subject.listeners).to include an_object_having_attributes(
            subscriber: AutoSubscribingSubscriber
          )
        end
      end

      context 'when it fails to subscribe' do
        it "doesn't make it into the listeners list" do
          expect(subject.listeners).not_to include an_object_having_attributes(
            subscriber: FailingAutoSubscribingSubscriber
          )
        end
      end
    end
  end
end
