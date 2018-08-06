module Subserver
  class Rails < ::Rails::Engine
    # We need to setup this up before any application configuration which might
    # change Subserver middleware.
    #
    # This hook happens after `Rails::Application` is inherited within
    # config/application.rb and before config is touched, usually within the
    # class block. Definitely before config/environments/*.rb and
    # config/initializers/*.rb.
    config.before_configuration do
      if ::Rails::VERSION::MAJOR < 5 && defined?(::ActiveRecord)
        Subserver.middleware do |chain|
          require 'subserver/middleware/active_record'
          chain.add Subserver::Middleware::ActiveRecord
        end
      end
    end

    config.after_initialize do
      # This hook happens after all initializers are run, just before returning
      # from config/environment.rb back to subserver/cli.rb.
      # We have to add the reloader after initialize to see if cache_classes has
      # been turned on.
      #
      Subserver.configure do |_|

        Subserver.options[:subscriber_dir] = ::Rails.root.join('app', 'subscribers')

        if ::Rails::VERSION::MAJOR >= 5
          Subserver.options[:reloader] = Subserver::Rails::Reloader.new
        end
      end
    end

    class Reloader
      def initialize(app = ::Rails.application)
        @app = app
      end

      def call
        @app.reloader.wrap do
          yield
        end
      end

      def inspect
        "#<Subserver::Rails::Reloader @app=#{@app.class.name}>"
      end
    end
  end if defined?(::Rails)
end

if defined?(::Rails) && ::Rails::VERSION::MAJOR < 4
  $stderr.puts("**************************************************")
  $stderr.puts("WARNING: Subserver is not supported on Rails < 4. Please Update to a newer version of Rails.")
  $stderr.puts("**************************************************")
end