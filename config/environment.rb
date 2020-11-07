# Load the Rails application.
require_relative 'application'

app_environment_variables = Rails.root.join("../shared/config/app_environment_variables.rb")
load(app_environment_variables) if Rails.env.development? # File.exists?(app_environment_variables)

# Initialize the Rails application.
Rails.application.initialize!
