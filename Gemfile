instance_eval File.read("Gemfile.common")

# Use Redis adapter to run Action Cable in production
gem 'redis', '~> 3.0'
# Use ActiveModel has_secure_password
gem 'bcrypt', '~> 3.1.7'
# database
gem 'mongoid_includes'

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
gem 'rack-cors'

gem 'newrelic_rpm'

group :test do
  gem 'database_cleaner', '~> 1.6.1'
  gem 'shoulda-matchers', '~> 3.1'
end

group :development, :test do
  # Use RSpec for specs
  gem 'rspec-rails', '>= 3.5.0'

  # Use Factory Bot for generating random test data
  gem 'factory_bot_rails', '~> 4.8.2'
end

group :development do
  gem "better_errors"
  gem "binding_of_caller"
  gem 'listen', '>= 3.0.5', '< 3.2'
end

gem 'graphql'
gem 'graphoid', path: 'gems/graphoid'
gem 'apollo_upload_server', '2.0.0.beta.1'
gem "activesupport", "~> 5.1"
gem 'restforce', "~> 5.0.0"
