module Subserver
  module Testing
    class Pubsub

      class Topic
        def publish(data)
          true
        end
      end

      def topic(name)
        Topic.new
      end

    end
  end
end