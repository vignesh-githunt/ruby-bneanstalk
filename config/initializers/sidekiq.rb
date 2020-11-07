if Rails.env.production?
  Sidekiq.configure_server do |config|
    config.redis = { url: "#{ENV['REDIS_PORT_6379_TCP_ADDR']}" }
    config.error_handlers << Proc.new { |exception, context_hash| SidekiqErrorService.notify(exception, context_hash) }
  end

  Sidekiq.configure_client do |config|
    config.redis = { url: "#{ENV['REDIS_PORT_6379_TCP_ADDR']}" }
  end
else
  Sidekiq.configure_server do |config|
    config.error_handlers << Proc.new { |exception, context_hash| SidekiqErrorService.notify(exception, context_hash) }
  end
end
