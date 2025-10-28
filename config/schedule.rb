# Schedule for price updates using sidekiq-cron or whenever gem
# For now, prices can be updated manually or triggered via the job

# Configuration for sidekiq-cron:
Sidekiq::Cron::Job.create(
  name: "Weekly Price Update Job",
  cron: "0 9 * * 1", # Every Monday at 9:00 AM
  class: "PriceUpdateJob"
)

# Alternative: Add sidekiq-cron to Gemfile and configure here
# Or use whenever gem for cron-based scheduling

# Manual trigger example for testing:
# PriceUpdateJob.perform_async
