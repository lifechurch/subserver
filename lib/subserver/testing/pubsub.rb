module Subserver
  module Testing
    class Pubsub

      class Topic
        def publish(data, attributes = {})
          true
        end
      end

      def topic(name, project: nil, skip_lookup: nil, async: nil)
        Topic.new
      end

    end
  end
end