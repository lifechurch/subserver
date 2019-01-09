require 'spec_helper'
require_relative '../lib/subserver/listener'
require_relative '../lib/subserver/manager'

RSpec.describe Subserver do

  describe 'json processing' do
    it 'loads json' do
      expect(Subserver.load_json("{\"foo\":\"bar\"}")).to eq({"foo" => "bar"})
    end

    it 'dumps json' do
      expect(Subserver.dump_json({ "foo": "bar"})).to eq('{"foo":"bar"}')
    end
  end

  describe 'load config' do
    it 'loads when file exists'
    it 'errors when file doesn\'t exit'
  end

  describe 'live cycle events' do

    let(:testclass) {
      Class.new do 
        def ping
          true
        end
      end
    }

    let(:test_subscriber) { 
      Class.new do 
        include Subserver::Subscriber 
        subserver_options subscription: "test-subscription-1"

        def perform
          true
        end
      end
    }

    before do
      @tester = testclass.new
      Subserver.configure do |config|
        config.on(:listener_startup) do 
          @tester.ping
        end 
      end

      @manager = instance_double("Subserver::Manager")
      allow(@manager).to receive(:options) { Subserver.options }
    end

    describe 'listener_startup event' do
      it 'runs when listener started' do
        expect(@tester).to receive(:ping)
        listener = Subserver::Listener.new(@manager, test_subscriber)
        listener.fire_event(:listener_startup, reverse: false, reraise: true)
      end
    end
  end
  
end