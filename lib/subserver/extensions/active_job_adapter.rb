# ActiveJob docs: http://edgeguides.rubyonrails.org/active_job_basics.html
# Example adapters ref: https://github.com/rails/rails/tree/master/activejob/lib/active_job/queue_adapters

module ActiveJob
  module QueueAdapters
    # == Subserver adapter for Active Job
    #
    # To use Subserver set the queue_adapter config to +:subserver+.
    #
    #   Rails.application.config.active_job.queue_adapter = :subserver
    class SubserverAdapter
      delegate :client, :topic, to: :class

      class << self
        delegate :client, to: Subserver::Pubsub

        def instance
          @instance ||= new
        end

        def enqueue(job)
          instance.enqueue(job)
        end

        def enqueue_at(job, timestamp)
          instance.enqueue_at(job, timestamp)
        end

        def processor_prefix
          @processor_prefix ||= Rails.application.class.parent_name.downcase +
                                '-' +
                                ENV.fetch('DEPLOYMENT_NAME', Rails.env).downcase
        end

        def topic_name
          "#{processor_prefix}-active-job-jobs"
        end

        def topic
          @topic ||= client.topic(topic_name) || client.create_topic(topic_name)
        end

        def subscription_name
          "#{processor_prefix}-active-job-processor"
        end

        def subscription
          topic.subscription subscription_name
        end

        def create_subscription
          topic.subscribe subscription_name
        end
      end

      def enqueue(job, options = {}) #:nodoc:
        topic.publish job.serialize.to_json, options
      end

      def enqueue_at(job, timestamp) #:nodoc:
        enqueue job, delay_seconds: calculate_delay(timestamp)
      end

      private

      def calculate_delay(timestamp)
        (timestamp - Time.current.to_f).round
      end

      def generate_message(job, options = {})
        { message_body: job.serialize }.reverse_merge options
      end

      class JobWrapper #:nodoc:
        include Subserver::Subscriber

        def self.ensure_subscription_exists
          SubserverAdapter.subscription || SubserverAdapter.create_subscription
        end

        subserver_options subscription: SubserverAdapter.subscription_name

        def perform(received_message)
          data = ActiveSupport::JSON.decode received_message.data
          Base.execute data
          received_message.acknowledge!
        end
      end
    end
  end
end
