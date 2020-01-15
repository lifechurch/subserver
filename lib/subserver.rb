require 'json'

require 'subserver/version'
fail "Subserver #{Subserver::VERSION} does not support Ruby versions below 2.3.1." if RUBY_PLATFORM != 'java' && Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.3.1')

require 'subserver/logging'
require 'subserver/pubsub'
require 'subserver/health'
require 'subserver/subscriber'
require 'subserver/middleware/chain'

module Subserver
  NAME = 'Subserver'
  LICENSE = 'Subserver is licensed under MIT.'

  DEFAULTS = {
    project_id: nil,
    credentials: nil,
    queues: [],
    labels: [],
    require: '.',
    subscriber_dir: './subscribers',
    environment: nil,
    timeout: 35,
    error_handlers: [],
    death_handlers: [],
    lifecycle_events: {
      startup: [],
      listener_startup: [],
      quiet: [],
      shutdown: [],
      heartbeat: [],
    },
    reloader: proc { |&block| block.call },
  }

  DEFAULT_SUBSCRIBER_OPTIONS = {
    subscription: nil,
    deadline: 60,
    streams: 2, 
    threads: {
      callback: 4,
      push: 2
    },
    inventory: 1000,
    queue: 'default'
  }


  def self.options
    @options ||= load_config
  end

  def self.options=(opts)
    @options = opts
  end

  def self.configure
    yield self
  end

  def self.load_config(file=nil)
    opts = DEFAULTS.dup
    file = Dir["config/subserver.yml*"].first if file.nil?
    return opts unless file && File.exists?(file)
    opts.merge(parse_config(file))
  end

  def self.load_json(string)
    JSON.parse(string)
  end

  def self.dump_json(object)
    JSON.generate(object)
  end

  def self.logger
    Subserver::Logging.logger
  end

  def self.logger=(log)
    Subserver::Logging.logger = log
  end

  def self.health_server
    @health_server ||= Subserver::Health.new
  end

  def self.pubsub_client
    Subserver::Pubsub.client
  end

  def self.middleware
    @chain ||= default_middleware
    yield @chain if block_given?
    @chain
  end

  def self.default_middleware
    Middleware::Chain.new
  end

  def self.default_subscriber_options=(hash)
    @default_subscriber_options = default_subscriber_options.merge(Hash[hash.map{|k, v| [k.to_s, v]}])
  end

  def self.default_subscriber_options
    defined?(@default_subscriber_options) ? @default_subscriber_options : DEFAULT_SUBSCRIBER_OPTIONS
  end

  # Death handlers are called when all retries for a job have been exhausted and
  # the job dies.  It's the notification to your application
  # that this job will not succeed without manual intervention.
  #
  # Subserver.configure do |config|
  #   config.death_handlers << ->(job, ex) do
  #   end
  # end
  def self.death_handlers
    options[:death_handlers]
  end

  # Register a proc to handle any error which occurs within the Subserver process.
  #
  #   Subserver.configure do |config|
  #     config.error_handlers << proc {|ex,ctx_hash| MyErrorService.notify(ex, ctx_hash) }
  #   end
  #
  # The default error handler logs errors to Subserver.logger.
  def self.error_handlers
    self.options[:error_handlers]
  end

  # Register a block to run at a point in the Subserver lifecycle.
  # :startup, :quiet or :shutdown are valid events.
  #
  #   Subserver.configure do |config|
  #     config.on(:shutdown) do
  #       puts "Goodbye cruel world!"
  #     end
  #   end
  def self.on(event, &block)
    raise ArgumentError, "Symbols only please: #{event}" unless event.is_a?(Symbol)
    raise ArgumentError, "Invalid event name: #{event}" unless options[:lifecycle_events].key?(event)
    options[:lifecycle_events][event] << block
  end

  # We are shutting down Subserver but what about workers that
  # are working on some long job?  This error is
  # raised in workers that have not finished within the hard
  # timeout limit.  This is needed to rollback db transactions,
  # otherwise Ruby's Thread#kill will commit.
  # DO NOT RESCUE THIS ERROR IN YOUR SUBSCRIBERS
  class Shutdown < Interrupt; end

  private
  
  def self.parse_config(cfile)
    opts = {}
    if File.exist?(cfile)
      opts = YAML.load(ERB.new(IO.read(cfile)).result) || opts

      if opts.respond_to? :deep_symbolize_keys!
        opts.deep_symbolize_keys!
      else
        symbolize_keys_deep!(opts)
      end

    else
      # allow a non-existent config file so Subserver
      # can be deployed by cap with just the defaults.
    end
    opts
  end

  def self.symbolize_keys_deep!(hash)
    hash.keys.each do |k|
      symkey = k.respond_to?(:to_sym) ? k.to_sym : k
      hash[symkey] = hash.delete k
      symbolize_keys_deep! hash[symkey] if hash[symkey].kind_of? Hash
    end
  end

end

require 'subserver/rails' if defined?(::Rails::Engine)