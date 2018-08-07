# frozen_string_literal: true
$stdout.sync = true

require 'yaml'
require 'singleton'
require 'optparse'
require 'erb'
require 'fileutils'

require 'subserver'
require 'subserver/util'

module Subserver
  class CLI
    include Util
    include Singleton unless $TESTING

    attr_accessor :code
    attr_accessor :launcher
    attr_accessor :environment

    def initialize
      @code = nil
    end

    def parse(args=ARGV)
      @code = nil

      setup_options(args)
      initialize_logger
      validate!
      daemonize
      write_pid
    end

    def jruby?
      defined?(::JRUBY_VERSION)
    end

    def run
      boot_system
      print_banner

      self_read, self_write = IO.pipe
      sigs = %w(INT TERM TTIN TSTP)
      # USR1 and USR2 don't work on the JVM
      if !jruby?
        sigs << 'USR1'
        sigs << 'USR2'
      end

      sigs.each do |sig|
        begin
          trap sig do
            self_write.write("#{sig}\n")
          end
        rescue ArgumentError
          puts "Signal #{sig} not supported"
        end
      end

      logger.info "Running in #{RUBY_DESCRIPTION}"
      logger.info Subserver::LICENSE

      # cache process identity
      Subserver.options[:identity] = identity

      # Touch middleware so it isn't lazy loaded by multiple threads.
      Subserver.middleware

      # Test Pubsub Connection
      if ENV['PUBSUB_EMULATOR_HOST']
        uri = URI.parse("http://#{ENV['PUBSUB_EMULATOR_HOST']}")
        http = Net::HTTP.new(uri.host, uri.port)
        begin
          response = http.request_get(uri)
        rescue Errno::ECONNREFUSED
          logger.error "Errno::ECONNREFUSED - Could not connect to Pubsub Emulator at connection: #{ENV['PUBSUB_EMULATOR_HOST']}."
          logger.info "If you are not intending to connect to the Pubsub Emulator remove the PUBSUB_EMULATOR_HOST environment variable."
          die(1)
        end
      else
        begin
          client = Subserver::Pubsub.client
        rescue StandardError => e
          logger.error "Pubsub Connection Error: #{e.message}"
          die(1)
        end
      end

      # Before this point, the process is initializing with just the main thread.
      # Starting here the process will now have multiple threads running.
      fire_event(:startup, reverse: false, reraise: true)

      logger.debug { "Middleware: #{Subserver.middleware.map(&:klass).join(', ')}" }

      if !options[:daemon]
        logger.info 'Starting processing, hit Ctrl-C to stop'
      end

      # Start Health Server
      @health_thread = safe_thread("health_server") do
        Subserver.health_server.start
      end 

      require 'subserver/launcher'
      @launcher = Subserver::Launcher.new(options)

      begin
        launcher.run

        while readable_io = IO.select([self_read])
          signal = readable_io.first[0].gets.strip
          handle_signal(signal)
        end
      rescue Interrupt
        logger.info 'Shutting down'
        launcher.stop
        exit(0)
      end
    end

    def self.banner
%q{
================================
           Subserver
================================
}
    end

    SIGNAL_HANDLERS = {
      # Ctrl-C in terminal
      'INT' => ->(cli) { raise Interrupt },
      # TERM is the signal that Subserver must exit.
      # Heroku sends TERM and then waits 30 seconds for process to exit.
      'TERM' => ->(cli) { raise Interrupt },
      'USR1' => ->(cli) {
        Subserver.logger.info "Received USR1, no longer accepting new work"
        cli.launcher.quiet
      },
      'TSTP' => ->(cli) {
        Subserver.logger.info "Received TSTP, no longer accepting new work"
        cli.launcher.quiet
      },
      'USR2' => ->(cli) {
        if Subserver.options[:logfile]
          Subserver.logger.info "Received USR2, reopening log file"
          Subserver::Logging.reopen_logs
        end
      },
      'TTIN' => ->(cli) {
        Thread.list.each do |thread|
          Subserver.logger.warn "Thread TID-#{(thread.object_id ^ ::Process.pid).to_s(36)} #{thread['subserver_label']}"
          if thread.backtrace
            Subserver.logger.warn thread.backtrace.join("\n")
          else
            Subserver.logger.warn "<no backtrace available>"
          end
        end
      },
    }

    def handle_signal(sig)
      Subserver.logger.debug "Got #{sig} signal"
      handy = SIGNAL_HANDLERS[sig]
      if handy
        handy.call(self)
      else
        Subserver.logger.info { "No signal handler for #{sig}" }
      end
    end

    private unless $TESTING

    def print_banner
      # Print logo and banner for development
      if environment == 'development' && $stdout.tty?
        puts Subserver::CLI.banner
      end
    end

    def daemonize
      return unless options[:daemon]

      raise ArgumentError, "You really should set a logfile if you're going to daemonize" unless options[:logfile]
      files_to_reopen = []
      ObjectSpace.each_object(File) do |file|
        files_to_reopen << file unless file.closed?
      end

      ::Process.daemon(true, true)

      files_to_reopen.each do |file|
        begin
          file.reopen file.path, "a+"
          file.sync = true
        rescue ::Exception
        end
      end

      [$stdout, $stderr].each do |io|
        File.open(options[:logfile], 'ab') do |f|
          io.reopen(f)
        end
        io.sync = true
      end
      $stdin.reopen('/dev/null')

      initialize_logger
    end

    def set_environment(cli_env)
      @environment = cli_env || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
    end

    alias_method :die, :exit
    alias_method :☠, :exit

    def setup_options(args)
      opts = parse_options(args)
      set_environment opts[:environment]

      cfile = opts[:config_file]
      opts = Subserver.load_config(cfile).merge(opts)

      Subserver.options = opts
    end

    def options
      Subserver.options
    end

    def boot_system
      ENV['RACK_ENV'] = ENV['RAILS_ENV'] = environment

      raise ArgumentError, "#{options[:require]} does not exist" unless File.exist?(options[:require])

      if File.directory?(options[:require])
        require 'rails'
        if ::Rails::VERSION::MAJOR < 4
          raise "Subserver does not support this version of Rails."
        elsif ::Rails::VERSION::MAJOR == 4
          require File.expand_path("#{options[:require]}/config/application.rb")
          ::Rails::Application.initializer "subserver.eager_load" do
            ::Rails.application.config.eager_load = true
          end
          require 'subserver/rails'
          require File.expand_path("#{options[:require]}/config/environment.rb")
        else
          require 'subserver/rails'
          require File.expand_path("#{options[:require]}/config/environment.rb")
        end
        options[:tag] ||= default_tag
      else
        not_required_message = "#{options[:require]} was not required, you should use an explicit path: " +
            "./#{options[:require]} or /path/to/#{options[:require]}"

        require(options[:require]) || raise(ArgumentError, not_required_message)
      end
    end

    def default_tag
      dir = ::Rails.root
      name = File.basename(dir)
      if name.to_i != 0 && prevdir = File.dirname(dir) # Capistrano release directory?
        if File.basename(prevdir) == 'releases'
          return File.basename(File.dirname(prevdir))
        end
      end
      name
    end

    def validate!
      options[:queues] << 'default' if options[:queues].empty?

      if !File.exist?(options[:require]) ||
         (File.directory?(options[:require]) && !File.exist?("#{options[:require]}/config/application.rb"))
        logger.info "=================================================================="
        logger.info "  Please point subserver to a Rails 4/5 application or a Ruby file  "
        logger.info "  to load your subscriber classes with -r [DIR|FILE]."
        logger.info "=================================================================="
        logger.info @parser
        die(1)
      end

      raise ArgumentError, "#{timeout}: #{options[:timeout]} is not a valid value" if options.has_key?(:timeout) && options[:timeout].to_i <= 0
    end

    def parse_options(argv)
      opts = {}

      @parser = OptionParser.new do |o|
        o.on "-c", "--credentials PATH", "Path to Google Cloud credentials JSON file." do |arg|
          opts[:credentials] = arg
        end

        o.on '-d', '--daemon', "Daemonize process" do |arg|
          opts[:daemon] = arg
        end

        o.on '-e', '--environment ENV', "Application environment" do |arg|
          opts[:environment] = arg
        end

        o.on '-g', '--tag TAG', "Process tag for procline" do |arg|
          opts[:tag] = arg
        end

        o.on '-p', '--project ID', "Google Cloud Project ID" do |arg|
          opts[:project_id] = arg
        end

        o.on "-q", "--queue QUEUE", "Subscriber queues to process with this server" do |arg|
          queue = arg
          opts = (opts[:queues] ||= []) << queue
        end

        o.on '-r', '--require [PATH|DIR]', "Location of Rails application with subscribers or file to require" do |arg|
          opts[:require] = arg
        end

        o.on '-t', '--timeout NUM', "Shutdown timeout" do |arg|
          opts[:timeout] = Integer(arg)
        end

        o.on "-v", "--verbose", "Print more verbose output" do |arg|
          opts[:verbose] = arg
        end

        o.on '-C', '--config PATH', "path to YAML config file" do |arg|
          opts[:config_file] = arg
        end

        o.on '-L', '--logfile PATH', "path to writable logfile" do |arg|
          opts[:logfile] = arg
        end

        o.on '-P', '--port PORT', "port to expose health check on" do |arg|
          opts[:health_port] = arg
        end

        o.on '-V', '--version', "Print version and exit" do |arg|
          puts "Subserver #{Subserver::VERSION}"
          die(0)
        end
      end

      @parser.banner = "subserver [options]"
      @parser.on_tail "-h", "--help", "Show help" do
        logger.info @parser
        die 1
      end
      @parser.parse!(argv)

      opts
    end

    def initialize_logger
      Subserver::Logging.initialize_logger(options[:logfile]) if options[:logfile]
      Subserver.logger.level = ::Logger::DEBUG if options[:verbose]
    end

    def write_pid
      if path = options[:pidfile]
        pidfile = File.expand_path(path)
        File.open(pidfile, 'w') do |f|
          f.puts ::Process.pid
        end
      end
    end

  end
end
