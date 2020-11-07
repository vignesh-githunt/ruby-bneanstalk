namespace :auth do
  task :plugin_token => :environment do
    email = "engineering@outboundworks.com"
    token = User.find_by(email: email).plugin_token
    puts email
    puts "X-Plugin-Token: #{token}"
  end
end
