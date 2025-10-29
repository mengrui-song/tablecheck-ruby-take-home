class DynamicPricing::CompetitorAnalyzer
  attr_reader :product

  def initialize(product, competitor_data = nil)
    @product = product
    @competitor_data = competitor_data
  end

  def analyze_and_adjust(our_price, competitor_data = nil)
    adjustment = calculate_competitor_adjustment(our_price, competitor_data)
    apply_competitor_adjustment(our_price, adjustment)
  end

  private

  def calculate_competitor_adjustment(our_price, competitor_data = nil)
    return { type: :none, amount: 0 } unless competitor_data

    competitor_item = competitor_data.find { |item| item["name"]&.downcase == product.name&.downcase }
    return { type: :none, amount: 0 } unless competitor_item

    competitor_price = competitor_item["price"]&.to_i
    return { type: :none, amount: 0 } unless competitor_price && competitor_price > 0

    price_difference = our_price - competitor_price
    percentage_difference = (price_difference.to_f / competitor_price * 100).round(2)

    if percentage_difference > 10
      { type: :reduce, amount: competitor_price, reason: "competitor_undercut", percentage: percentage_difference }
    elsif percentage_difference < -5
      { type: :increase, amount: [ our_price * 1.05, competitor_price * 0.95 ].min.to_i, reason: "competitor_premium", percentage: percentage_difference }
    else
      { type: :none, amount: 0, reason: "competitive_range", percentage: percentage_difference }
    end
  end

  def apply_competitor_adjustment(calculated_price, adjustment)
    case adjustment[:type]
    when :reduce
      [ adjustment[:amount], calculated_price * 0.8 ].max.to_i
    when :increase
      adjustment[:amount]
    else
      calculated_price
    end
  end
end
