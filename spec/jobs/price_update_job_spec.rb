require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe PriceUpdateJob, type: :job do
  before do
    Sidekiq::Testing.fake!
  end

  after do
    Sidekiq::Worker.clear_all
  end
  let!(:products) do
    3.times.map do |i|
      Product.create!(
        name: "Test Product #{i + 1}",
        category: 'Electronics',
        default_price: 100 + i * 10,
        quantity: 50,
        dynamic_price: 100 + i * 10
      )
    end
  end

  describe '#perform' do
    it 'updates prices for all products' do
      # Mock the dynamic pricing service to avoid external dependencies
      allow_any_instance_of(DynamicPricingService).to receive(:calculate_dynamic_price)

      job = PriceUpdateJob.new

      expect { job.perform }.not_to raise_error
    end

    it 'logs successful price updates' do
      # Set up products with different prices
      products.each_with_index do |product, index|
        product.update(dynamic_price: 10.0 + index)
      end

      # Mock the service to simulate price changes
      allow_any_instance_of(DynamicPricingService).to receive(:calculate_dynamic_price) do |service|
        product = service.instance_variable_get(:@product)
        product.update(dynamic_price: product.dynamic_price + 5.0)
      end

      expect(Rails.logger).to receive(:info).with(/Starting periodic price update job/)
      expect(Rails.logger).to receive(:info).with(/Price update job completed/)

      products.each do |product|
        expect(Rails.logger).to receive(:info)
          .with(/Updated price for #{product.name}/)
      end

      PriceUpdateJob.new.perform
    end

    it 'handles errors gracefully' do
      # Mock the service to raise an error for the first product
      allow_any_instance_of(DynamicPricingService).to receive(:calculate_dynamic_price) do |service|
        product = service.instance_variable_get(:@product)
        raise StandardError, "Test error" if product == products.first
      end

      expect(Rails.logger).to receive(:error)
        .with(/Failed to update price for product #{products.first.id}/)
      expect(Sidekiq.logger).to receive(:error)

      expect { PriceUpdateJob.new.perform }.not_to raise_error
    end

    it 'can be enqueued' do
      expect {
        PriceUpdateJob.perform_async
      }.to change(Sidekiq::Queues["pricing"], :size).by(1)
    end
  end
end
