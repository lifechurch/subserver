# 0.5.2
- Fix syntax issue

# 0.5.1
- Dependency updates

# 0.5.0
- Dependency updates
- google-cloud-pubsub 2.0

# 0.4.4
- Fixes `Subserver::Testing::Pubsub.topic` missing arguments 

# 0.4.3
- Dependency updates
- Ruby >=2.4
- google-cloud-pubsub ~> 1.7
- self.auto_subscribe method #25
- Subserver::Testing::Pubsub::Topic.publish now supports the `attributes` arugment

# 0.4.1
- Fix Listener#process_message error handling

# 0.4.0
- Adds listener_startup lifecycle event

# 0.3.0
- Adds Mocks for testing in applications

# 0.2.2
- Fix issue where multi-subscriber options were getting overridden

# 0.2.1
- Use Rails 5 reloader
- Fix ActiveRecord connection issues using ConnectionHandler
- Use Google's Default Enviroment Variables for fallback

# 0.2.0
- Adds PubSub connection testing
- Fixes a case where subserver would infinitly kill and respawn listeners
- Cleans up logger code

# 0.1.1
- Fixes connection handling

# 0.1.0
- Initial Public Release