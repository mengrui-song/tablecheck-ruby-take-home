require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe PriceUpdateJob, type: :job do
  before do
    Sidekiq::Testing.fake!
  end

  after do
    Sidekiq::Worker.clear_all
  end

  def mock_competitor_data
    {
      "products" => [
        { "name" => "Test Product 1", "price" => 120 },
        { "name" => "Test Product 2", "price" => 950 },
        { "name" => "Test Product 3", "price" => 85 }
      ]
    }
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
      # Mock the competitor pricing API fetch
      allow(CompetitorPricingApiClient).to receive(:fetch_prices).and_return(mock_competitor_data)

      # Mock the dynamic pricing service to avoid external dependencies
      allow_any_instance_of(DynamicPricingService).to receive(:calculate_dynamic_price).and_return(150)

      job = PriceUpdateJob.new

      expect { job.perform }.not_to raise_error
    end

    it 'logs successful price updates' do
      # Mock the competitor pricing API fetch
      allow(CompetitorPricingApiClient).to receive(:fetch_prices).and_return(mock_competitor_data)

      # Set up products with different prices
      products.each_with_index do |product, index|
        product.update(dynamic_price: 10.0 + index)
      end

      # Mock the service to return new prices without saving
      allow_any_instance_of(DynamicPricingService).to receive(:calculate_dynamic_price) do |service|
        product = service.instance_variable_get(:@product)
        product.dynamic_price + 5.0
      end

      expect(Rails.logger).to receive(:info).with(/Starting periodic price update job/).ordered
      expect(Rails.logger).to receive(:info).with("Fetched competitor data for pricing calculations")

      products.each_with_index do |product, index|
        old_price = 10.0 + index
        new_price = old_price + 5.0
        expect(Rails.logger).to receive(:info)
          .with("Updated price for #{product.name}: #{old_price.to_i} -> #{new_price}")
      end

      expect(Rails.logger).to receive(:info).with("Executed bulk update for #{products.size} products")
      expect(Rails.logger).to receive(:info).with(/Price update job completed/).ordered

      PriceUpdateJob.new.perform
    end

    it 'handles errors gracefully' do
      # Mock the competitor pricing API fetch
      allow(CompetitorPricingApiClient).to receive(:fetch_prices).and_return(mock_competitor_data)

      # Mock the service to raise an error for the first product
      allow_any_instance_of(DynamicPricingService).to receive(:calculate_dynamic_price) do |service|
        product = service.instance_variable_get(:@product)
        raise StandardError, "Test error" if product == products.first
      end

      expect(Rails.logger).to receive(:error)
        .with(/Failed to calculate price for product #{products.first.id}/)
      expect(Sidekiq.logger).to receive(:error).with(anything)

      expect { PriceUpdateJob.new.perform }.not_to raise_error
    end

    it 'can be enqueued' do
      expect {
        PriceUpdateJob.perform_async
      }.to change(Sidekiq::Queues["pricing"], :size).by(1)
    end
  end
end
