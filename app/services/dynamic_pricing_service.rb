class DynamicPricingService
  attr_reader :product

  def initialize(product)
    @product = product
  end

  def calculate_dynamic_price
    # Step 1: Base Price is the product's default price
    base_price = product.default_price

    # Step 2: Adjust the base price using demand and inventory factors
    demand_multiplier = demand_calculator.calculate_multiplier
    inventory_multiplier = inventory_calculator.calculate_multiplier
    calculated_price = (base_price * demand_multiplier * inventory_multiplier).round

    # Step 3: Adjust the price based on competitor pricing and default price
    adjusted_price = competitor_analyzer.analyze_and_adjust(calculated_price)

    # Step 4: Ensure final price is not below 80% of default price
    final_price = [ adjusted_price, (base_price * 0.8).round ].max

    product.update(dynamic_price: final_price)
    final_price
  end

  def self.update_all_prices
    Product.all.each do |product|
      new(product).calculate_dynamic_price
    rescue => e
      Rails.logger.error "Failed to update price for product #{product.id}: #{e.message}"
    end
  end

  private

  def demand_calculator
    @demand_calculator ||= DynamicPricing::DemandCalculator.new(product)
  end

  def inventory_calculator
    @inventory_calculator ||= DynamicPricing::InventoryCalculator.new(product)
  end

  def competitor_analyzer
    @competitor_analyzer ||= DynamicPricing::CompetitorAnalyzer.new(product)
  end
end
