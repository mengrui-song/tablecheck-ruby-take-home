require "bigdecimal"

class DynamicPricing::InventoryCalculator
  attr_reader :product

  def initialize(product)
    @product = product
  end

  def calculate_multiplier
    return 1.0 if product.quantity.nil? || product.quantity == 0

    base_multiplier = BigDecimal(quantity_multiplier.to_s)
    category_multiplier = BigDecimal(category_adjustment.to_s)

    (base_multiplier * category_multiplier).to_f.round(2)
  end

  private

  def quantity_multiplier
    case product.quantity
    when 1..50
      1.3   # Very low stock - premium pricing (bottom ~20%)
    when 51..100
      1.2   # Low stock - higher pricing (~20-40%)
    when 101..175
      1.1   # Medium-low stock - slight premium (~40-60%)
    when 176..250
      1.0   # Good stock - normal pricing (~60-80%)
    else
      0.9   # High stock - discounted pricing (top ~20%)
    end
  end

  def category_adjustment
    case product.category&.downcase
    when "footwear"
      1.05  # Footwear tends to have higher demand
    when "accessories"
      0.95  # Accessories are more price-sensitive
    when "clothing"
      1.0   # Clothing baseline
    else
      1.0   # Default for unknown categories
    end
  end
end
