class DynamicPricing::DemandCalculator
  attr_reader :product

  def initialize(product)
    @product = product
  end

  def calculate_multiplier
    # Stage 1: Volume-based stability check: No adjustment if insufficient data: < 10 transactions
    current_week_stats = get_weekly_demand_stats(Date.current.beginning_of_week)
    return 1.0 if insufficient_transaction_volume?(current_week_stats)

    # Stage 2: Growth rate calculation - week-over-week comparison
    previous_week_stats = get_weekly_demand_stats(1.week.ago.beginning_of_week)
    growth_rate = calculate_growth_rate(current_week_stats, previous_week_stats)

    # Stage 3: Weighted scoring - purchases > cart additions (price-range adjusted)
    weighted_growth = calculate_weighted_growth(growth_rate)

    # Stage 4: Tier-based adjustment - pricing ranges based on growth
    tier_multiplier = calculate_tier_multiplier(weighted_growth)

    # Stage 5: Smoothing & limiting - prevent drastic fluctuations
    smooth_and_limit_multiplier(tier_multiplier)
  end

  private

  # Stage 1: Check if product has sufficient transaction volume
  def insufficient_transaction_volume?(week_stats)
    return true if week_stats.nil?

    total_transactions = week_stats[:total] || 0
    total_transactions < 10
  end

  # Determine price range for product-specific tuning
  def get_price_range
    price = product.current_price || 0
    case price
    when 1..1000
      :low        # 1-1000
    when 1001..3000
      :medium     # 1001-3000
    when 3001..6000
      :high       # 3001-6000
    else
      :premium    # 6001+
    end
  end

  # Get price-range specific weights for purchases vs cart additions
  def get_price_range_weights
    case get_price_range
    when :low
      { purchase_weight: 0.8, cart_weight: 0.2 }  # Higher purchase weight for low-price items
    when :medium
      { purchase_weight: 0.7, cart_weight: 0.3 }  # Balanced weighting
    when :high
      { purchase_weight: 0.6, cart_weight: 0.4 }  # More cart consideration for high-price items
    when :premium
      { purchase_weight: 0.5, cart_weight: 0.5 }  # Equal weighting for premium items
    end
  end

  # Stage 2-1: Get weekly demand statistics for specified week
  def get_weekly_demand_stats(week_start)
    week_end = week_start.end_of_week

    # Purchase data (completed orders)
    paid_order_ids = Order.where(status: "paid", created_at: week_start..week_end).pluck(:id)
    purchases = product.order_items.where(order_id: paid_order_ids).sum(:quantity)

    # Cart addition data
    cart_additions = CartItem.where(
      product: product,
      created_at: week_start..week_end
    ).sum(:quantity)

    {
      purchases: purchases,
      cart_additions: cart_additions,
      total: purchases + cart_additions
    }
  end

  # Stage 2-2: Calculate growth rates
  def calculate_growth_rate(current_stats, previous_stats)
    # Handle nil or invalid stats
    return { purchases: 0, cart_additions: 0, total: 0 } if previous_stats.nil? || previous_stats[:total].nil? || previous_stats[:total] == 0

    {
      purchases: safe_growth_calculation(current_stats[:purchases], previous_stats[:purchases]),
      cart_additions: safe_growth_calculation(current_stats[:cart_additions], previous_stats[:cart_additions]),
      total: safe_growth_calculation(current_stats[:total], previous_stats[:total])
    }
  end

  def safe_growth_calculation(current, previous)
    return 0 if previous.nil? || previous == 0 || current.nil?
    ((current - previous).to_f / previous * 100).round(2)
  end

  # Stage 3: Weighted growth - purchases weighted higher than cart additions (price-range adjusted)
  def calculate_weighted_growth(growth_rate)
    return 0.0 if growth_rate.nil?

    weights = get_price_range_weights
    purchase_weight = weights[:purchase_weight]
    cart_weight = weights[:cart_weight]

    purchases_growth = growth_rate[:purchases] || 0
    cart_growth = growth_rate[:cart_additions] || 0

    (purchases_growth * purchase_weight + cart_growth * cart_weight).round(2)
  end

  # Stage 4: Tier-based multiplier based on growth rate ranges (price-range adjusted)
  def calculate_tier_multiplier(weighted_growth)
    return 1.0 if weighted_growth.nil? || !weighted_growth.is_a?(Numeric)

    price_range = get_price_range

    # Price-range specific thresholds and multipliers
    case price_range
    when :low
      calculate_low_price_tier(weighted_growth)
    when :medium
      calculate_medium_price_tier(weighted_growth)
    when :high
      calculate_high_price_tier(weighted_growth)
    when :premium
      calculate_premium_price_tier(weighted_growth)
    else
      1.0
    end
  end

  # Low price range (1-1000): More aggressive pricing, higher sensitivity
  def calculate_low_price_tier(weighted_growth)
    case weighted_growth
    when -Float::INFINITY..-25
      0.75  # More aggressive price reduction
    when -25...-10
      0.85  # Moderate price reduction
    when -10...-3
      0.92  # Small price reduction
    when -3..3
      1.0   # Stable
    when 3...10
      1.08  # Small price increase
    when 10...25
      1.20  # Moderate price increase
    when 25...40
      1.35  # Strong price increase
    when 40..Float::INFINITY
      1.50  # Maximum price increase
    else
      1.0
    end
  end

  # Medium price range (1001-3000): Balanced approach
  def calculate_medium_price_tier(weighted_growth)
    case weighted_growth
    when -Float::INFINITY..-30
      0.8   # Significant decline
    when -30...-15
      0.9   # Moderate decline
    when -15...-5
      0.95  # Slight decline
    when -5..5
      1.0   # Stable
    when 5...15
      1.05  # Slight growth
    when 15...30
      1.15  # Moderate growth
    when 30...50
      1.25  # Strong growth
    when 50..Float::INFINITY
      1.35  # Very strong growth
    else
      1.0
    end
  end

  # High price range (3001-6000): Conservative approach
  def calculate_high_price_tier(weighted_growth)
    case weighted_growth
    when -Float::INFINITY..-35
      0.85  # Conservative price reduction
    when -35...-20
      0.92  # Moderate price reduction
    when -20...-8
      0.96  # Small price reduction
    when -8..8
      1.0   # Wider stable range
    when 8...20
      1.03  # Conservative price increase
    when 20...35
      1.08  # Moderate price increase
    when 35...60
      1.15  # Strong price increase
    when 60..Float::INFINITY
      1.25  # Maximum conservative increase
    else
      1.0
    end
  end

  # Premium price range (6001+): Very conservative, prestige-focused
  def calculate_premium_price_tier(weighted_growth)
    case weighted_growth
    when -Float::INFINITY..-40
      0.90  # Minimal price reduction to maintain prestige
    when -40...-25
      0.95  # Small price reduction
    when -25...-10
      0.98  # Very small price reduction
    when -10..10
      1.0   # Very wide stable range
    when 10...25
      1.02  # Minimal price increase
    when 25...40
      1.05  # Small price increase
    when 40...70
      1.10  # Moderate price increase
    when 70..Float::INFINITY
      1.20  # Conservative maximum increase
    else
      1.0
    end
  end

  # Stage 5: Smoothing and limiting mechanism
  def smooth_and_limit_multiplier(new_multiplier)
    return 1.0 if new_multiplier.nil? || !new_multiplier.is_a?(Numeric)

    # Get previous multiplier to avoid drastic changes
    last_multiplier = product.last_demand_multiplier&.to_f || 1.0

    # Limit maximum change per adjustment (15% max change)
    max_change = 0.15
    change = new_multiplier - last_multiplier

    # Apply smoothing
    if change.abs > max_change
      smoothed_multiplier = last_multiplier + (change > 0 ? max_change : -max_change)
    else
      smoothed_multiplier = new_multiplier
    end

    # Final bounds: between 0.7 and 1.5
    final_multiplier = [ [ smoothed_multiplier, 0.7 ].max, 1.5 ].min

    # Store current multiplier for next calculation
    product.update(last_demand_multiplier: final_multiplier)

    final_multiplier
  end
end
