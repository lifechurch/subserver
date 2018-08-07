require 'spec_helper'

RSpec.describe Subserver::Health do

  before do
    @server = ::Subserver::Health.new
    Thread.new do
      @server.start  
    end 
  end

  it 'responds healthy' do
    uri = URI.parse("http://localhost:4081")
    http = Net::HTTP.new(uri.host, uri.port)
    expect(http.request_get(uri).code.to_i).to eq(200)
  end

  after do
    @server.stop
  end
  
end