class OrderCleanupJob < ApplicationJob
  queue_as :default

  def perform
    # Cleanup expired orders and return inventory
    Order.cleanup_expired!
    Rails.logger.info "Cleaned up expired orders at #{Time.current}"
  end
end
