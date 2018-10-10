module Subserver
  module Testing
    class Pubsub

      class Topic
        def publish
          true
        end
      end

      def topic
        Topic.new
      end

    end
  end
end