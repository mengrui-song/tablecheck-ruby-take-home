require "sidekiq"
require "sidekiq-cron"

# Configure Redis URL for development if not set
redis_url = ENV.fetch("REDIS_URL")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }

  # Load cron jobs from schedule.rb
  schedule_file = Rails.root.join("config", "schedule.rb")
  if File.exist?(schedule_file)
    load schedule_file
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
