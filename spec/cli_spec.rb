require 'spec_helper'

RSpec.describe Subserver::CLI do

  before do
    @cli = Subserver::CLI.new
  end

  describe "setup" do
    it "uses default options with no args" do
      @cli.setup_options([])
      expect(Subserver.options).to eq(Subserver::DEFAULTS)
    end
  end


  after do
  end
  
end