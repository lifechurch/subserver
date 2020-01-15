module Subserver
  module Subscriber

    def self.included(base)
      base.extend(ClassMethods)
      base.subserver_class_attribute :subserver_options_hash
    end

    def logger
      Subserver.logger
    end

    module ClassMethods

      def can_auto_subscribe?
        respond_to? :ensure_subscription_exists
      end

      def subserver_options(opts={})
        self.subserver_options_hash = get_subserver_options.merge(opts)
      end

      def get_subserver_options
        self.subserver_options_hash ||= Subserver.default_subscriber_options
      end

      def subserver_class_attribute(*attrs)
        instance_reader = true
        instance_writer = true

        attrs.each do |name|
          singleton_class.instance_eval do
            undef_method(name) if method_defined?(name) || private_method_defined?(name)
          end
          define_singleton_method(name) { nil }

          ivar = "@#{name}"

          singleton_class.instance_eval do
            m = "#{name}="
            undef_method(m) if method_defined?(m) || private_method_defined?(m)
          end
          define_singleton_method("#{name}=") do |val|
            singleton_class.class_eval do
              undef_method(name) if method_defined?(name) || private_method_defined?(name)
              define_method(name) { val }
            end

            if singleton_class?
              class_eval do
                undef_method(name) if method_defined?(name) || private_method_defined?(name)
                define_method(name) do
                  if instance_variable_defined? ivar
                    instance_variable_get ivar
                  else
                    singleton_class.send name
                  end
                end
              end
            end
            val
          end

          if instance_reader
            undef_method(name) if method_defined?(name) || private_method_defined?(name)
            define_method(name) do
              if instance_variable_defined?(ivar)
                instance_variable_get ivar
              else
                self.class.public_send name
              end
            end
          end

          if instance_writer
            m = "#{name}="
            undef_method(m) if method_defined?(m) || private_method_defined?(m)
            attr_writer name
          end
        end
      end
    end

  end
end
