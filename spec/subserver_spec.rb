require 'spec_helper'

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
  
end