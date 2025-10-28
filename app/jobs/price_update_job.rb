class PriceUpdateJob
  include Sidekiq::Job

  sidekiq_options retry: 3, queue: :pricing

  def perform
    Rails.logger.info "Starting periodic price update job"

    start_time = Time.current
    updated_count = 0

    Product.all.each do |product|
      begin
        old_price = product.dynamic_price
        DynamicPricingService.new(product).calculate_dynamic_price
        new_price = product.reload.dynamic_price

        if old_price != new_price
          updated_count += 1
          Rails.logger.info "Updated price for #{product.name}: #{old_price} -> #{new_price}"
        end
      rescue => e
        Rails.logger.error "Failed to update price for product #{product.id} (#{product.name}): #{e.message}"
        Sidekiq.logger.error e.backtrace.join("\n")
      end
    end

    duration = Time.current - start_time
    Rails.logger.info "Price update job completed. Updated #{updated_count} products in #{duration.round(2)} seconds"
  end
end
