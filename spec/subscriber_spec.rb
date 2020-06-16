require 'spec_helper'
require_relative '../lib/subserver/subscriber'

RSpec.describe Subserver::Subscriber do
  let :example_subscriber_class do
    Class.new do
      include Subserver::Subscriber
    end
  end

  describe '.auto_subscribe?' do
    context 'when the subscriber class does not implement .auto_subscribe' do
      it 'returns false' do
        expect(example_subscriber_class.auto_subscribe?).to be false
      end
    end

    context 'when the subscriber class implements .auto_subscribe' do
      let :example_subscriber_class do
        Class.new do
          include Subserver::Subscriber
          def self.auto_subscribe; true; end
        end
      end

      it 'returns true' do
        expect(example_subscriber_class.auto_subscribe?).to be true
      end
    end
  end
end
