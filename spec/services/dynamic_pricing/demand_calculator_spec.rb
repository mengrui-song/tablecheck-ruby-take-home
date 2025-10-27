require 'rails_helper'

RSpec.describe DynamicPricing::DemandCalculator, type: :service do
  let(:product) do
    Product.create!(
      name: 'Test Product',
      category: 'Electronics',
      default_price: 1500,
      dynamic_price: 1500,
      quantity: 100,
      last_demand_multiplier: 1.0
    )
  end
  let(:calculator) { described_class.new(product) }
  let(:current_week_start) { Date.current.beginning_of_week }
  let(:previous_week_start) { 1.week.ago.beginning_of_week }

  before do
    # Mock Date.current to ensure consistent testing
    allow(Date).to receive(:current).and_return(Date.new(2025, 1, 15)) # Wednesday
  end

  describe '#calculate_multiplier' do
    context 'when product has insufficient transaction volume' do
      before do
        allow(calculator).to receive(:get_weekly_demand_stats)
          .with(current_week_start)
          .and_return({ purchases: 3, cart_additions: 5, total: 8 })
      end

      it 'returns 1.0 for products with less than 10 total transactions' do
        expect(calculator.calculate_multiplier).to eq(1.0)
      end
    end

    context 'when product has sufficient transaction volume' do
      let(:current_stats) { { purchases: 15, cart_additions: 10, total: 25 } }
      let(:previous_stats) { { purchases: 10, cart_additions: 8, total: 18 } }

      before do
        allow(calculator).to receive(:get_weekly_demand_stats)
          .with(current_week_start).and_return(current_stats)
        allow(calculator).to receive(:get_weekly_demand_stats)
          .with(previous_week_start).and_return(previous_stats)
      end

      it 'calculates and returns a demand multiplier' do
        result = calculator.calculate_multiplier
        expect(result).to be_a(Numeric)
        expect(result).to be_between(0.7, 1.5)
      end

      it 'updates the product last_demand_multiplier' do
        expect { calculator.calculate_multiplier }
          .to change { product.reload.last_demand_multiplier }
      end
    end
  end

  describe '#insufficient_transaction_volume?' do
    it 'returns true when week_stats is nil' do
      expect(calculator.send(:insufficient_transaction_volume?, nil)).to be true
    end

    it 'returns true when total transactions is less than 10' do
      stats = { purchases: 3, cart_additions: 5, total: 8 }
      expect(calculator.send(:insufficient_transaction_volume?, stats)).to be true
    end

    it 'returns false when total transactions is 10 or more' do
      stats = { purchases: 6, cart_additions: 4, total: 10 }
      expect(calculator.send(:insufficient_transaction_volume?, stats)).to be false
    end

    it 'handles nil total gracefully' do
      stats = { purchases: 5, cart_additions: 3, total: nil }
      expect(calculator.send(:insufficient_transaction_volume?, stats)).to be true
    end
  end

  describe '#get_price_range' do
    context 'for different price ranges' do
      it 'returns :low for prices 1-1000' do
        product.update!(dynamic_price: 500)
        expect(calculator.send(:get_price_range)).to eq(:low)
      end

      it 'returns :medium for prices 1001-3000' do
        product.update!(dynamic_price: 2000)
        expect(calculator.send(:get_price_range)).to eq(:medium)
      end

      it 'returns :high for prices 3001-6000' do
        product.update!(dynamic_price: 4500)
        expect(calculator.send(:get_price_range)).to eq(:high)
      end

      it 'returns :premium for prices above 6000' do
        product.update!(dynamic_price: 8000)
        expect(calculator.send(:get_price_range)).to eq(:premium)
      end
    end
  end

  describe '#get_price_range_weights' do
    it 'returns correct weights for low price range' do
      product.update!(dynamic_price: 500)
      weights = calculator.send(:get_price_range_weights)
      expect(weights).to eq({ purchase_weight: 0.8, cart_weight: 0.2 })
    end

    it 'returns correct weights for medium price range' do
      product.update!(dynamic_price: 2000)
      weights = calculator.send(:get_price_range_weights)
      expect(weights).to eq({ purchase_weight: 0.7, cart_weight: 0.3 })
    end

    it 'returns correct weights for high price range' do
      product.update!(dynamic_price: 4500)
      weights = calculator.send(:get_price_range_weights)
      expect(weights).to eq({ purchase_weight: 0.6, cart_weight: 0.4 })
    end

    it 'returns correct weights for premium price range' do
      product.update!(dynamic_price: 8000)
      weights = calculator.send(:get_price_range_weights)
      expect(weights).to eq({ purchase_weight: 0.5, cart_weight: 0.5 })
    end
  end

  describe '#calculate_growth_rate' do
    let(:current_stats) { { purchases: 20, cart_additions: 15, total: 35 } }
    let(:previous_stats) { { purchases: 10, cart_additions: 10, total: 20 } }

    it 'calculates growth rates correctly' do
      result = calculator.send(:calculate_growth_rate, current_stats, previous_stats)

      expect(result[:purchases]).to eq(100.0)  # (20-10)/10 * 100
      expect(result[:cart_additions]).to eq(50.0)  # (15-10)/10 * 100
      expect(result[:total]).to eq(75.0)  # (35-20)/20 * 100
    end

    it 'handles nil previous_stats' do
      result = calculator.send(:calculate_growth_rate, current_stats, nil)
      expect(result).to eq({ purchases: 0, cart_additions: 0, total: 0 })
    end

    it 'handles zero previous total' do
      zero_previous = { purchases: 0, cart_additions: 0, total: 0 }
      result = calculator.send(:calculate_growth_rate, current_stats, zero_previous)
      expect(result).to eq({ purchases: 0, cart_additions: 0, total: 0 })
    end
  end

  describe '#safe_growth_calculation' do
    it 'calculates growth percentage correctly' do
      result = calculator.send(:safe_growth_calculation, 15, 10)
      expect(result).to eq(50.0)  # (15-10)/10 * 100
    end

    it 'handles zero previous value' do
      result = calculator.send(:safe_growth_calculation, 15, 0)
      expect(result).to eq(0)
    end

    it 'handles nil values' do
      expect(calculator.send(:safe_growth_calculation, nil, 10)).to eq(0)
      expect(calculator.send(:safe_growth_calculation, 15, nil)).to eq(0)
    end
  end

  describe '#calculate_weighted_growth' do
    let(:growth_rate) { { purchases: 50.0, cart_additions: 25.0, total: 40.0 } }

    context 'for medium price range (balanced weights)' do
      before { product.update!(dynamic_price: 2000) }

      it 'calculates weighted growth correctly' do
        # 50 * 0.7 + 25 * 0.3 = 35 + 7.5 = 42.5
        result = calculator.send(:calculate_weighted_growth, growth_rate)
        expect(result).to eq(42.5)
      end
    end

    context 'for low price range (purchase-heavy weights)' do
      before { product.update!(dynamic_price: 500) }

      it 'weights purchases more heavily' do
        # 50 * 0.8 + 25 * 0.2 = 40 + 5 = 45
        result = calculator.send(:calculate_weighted_growth, growth_rate)
        expect(result).to eq(45.0)
      end
    end

    it 'handles nil growth_rate' do
      result = calculator.send(:calculate_weighted_growth, nil)
      expect(result).to eq(0.0)
    end

    it 'handles missing keys in growth_rate' do
      incomplete_rate = { purchases: 30.0 }
      result = calculator.send(:calculate_weighted_growth, incomplete_rate)
      expect(result).to be_a(Numeric)
    end
  end

  describe '#calculate_tier_multiplier' do
    context 'for low price range products' do
      before { product.update!(dynamic_price: 500) }

      it 'returns aggressive reduction for significant decline' do
        result = calculator.send(:calculate_tier_multiplier, -30.0)
        expect(result).to eq(0.75)
      end

      it 'returns neutral for stable growth' do
        result = calculator.send(:calculate_tier_multiplier, 0.0)
        expect(result).to eq(1.0)
      end

      it 'returns aggressive increase for strong growth' do
        result = calculator.send(:calculate_tier_multiplier, 35.0)
        expect(result).to eq(1.35)
      end

      it 'returns maximum increase for very strong growth' do
        result = calculator.send(:calculate_tier_multiplier, 50.0)
        expect(result).to eq(1.50)
      end
    end

    context 'for premium price range products' do
      before { product.update!(dynamic_price: 8000) }

      it 'returns conservative reduction for significant decline' do
        result = calculator.send(:calculate_tier_multiplier, -50.0)
        expect(result).to eq(0.90)
      end

      it 'returns neutral for stable growth within wide range' do
        result = calculator.send(:calculate_tier_multiplier, 5.0)
        expect(result).to eq(1.0)
      end

      it 'returns conservative increase for strong growth' do
        result = calculator.send(:calculate_tier_multiplier, 50.0)
        expect(result).to eq(1.10)
      end

      it 'returns maximum conservative increase for very strong growth' do
        result = calculator.send(:calculate_tier_multiplier, 80.0)
        expect(result).to eq(1.20)
      end
    end

    it 'handles nil weighted_growth' do
      result = calculator.send(:calculate_tier_multiplier, nil)
      expect(result).to eq(1.0)
    end

    it 'handles non-numeric weighted_growth' do
      result = calculator.send(:calculate_tier_multiplier, "invalid")
      expect(result).to eq(1.0)
    end
  end

  describe '#smooth_and_limit_multiplier' do
    context 'when smoothing is required' do
      before { product.last_demand_multiplier = 1.0 }

      it 'limits maximum change to 15%' do
        # New multiplier 1.30, but should be limited to 1.15 (15% increase)
        result = calculator.send(:smooth_and_limit_multiplier, 1.30)
        expect(result).to eq(1.15)
      end

      it 'limits maximum decrease to 15%' do
        # New multiplier 0.70, but should be limited to 0.85 (15% decrease)
        result = calculator.send(:smooth_and_limit_multiplier, 0.70)
        expect(result).to eq(0.85)
      end
    end

    context 'when no smoothing is required' do
      before { product.last_demand_multiplier = 1.0 }

      it 'allows changes within 15% limit' do
        result = calculator.send(:smooth_and_limit_multiplier, 1.10)
        expect(result).to eq(1.10)
      end
    end

    context 'when applying final bounds' do
      before { product.last_demand_multiplier = 0.8 }

      it 'enforces minimum bound of 0.7' do
        result = calculator.send(:smooth_and_limit_multiplier, 0.6)
        expect(result).to eq(0.7)
      end

      it 'enforces maximum bound of 1.5' do
        product.last_demand_multiplier = 1.4
        result = calculator.send(:smooth_and_limit_multiplier, 1.6)
        expect(result).to eq(1.5)
      end
    end

    it 'handles nil last_demand_multiplier' do
      product.last_demand_multiplier = nil
      result = calculator.send(:smooth_and_limit_multiplier, 1.20)
      expect(result).to eq(1.15)  # Should use 1.0 as default and limit to 15% increase
    end

    it 'handles nil new_multiplier' do
      result = calculator.send(:smooth_and_limit_multiplier, nil)
      expect(result).to eq(1.0)
    end

    it 'handles non-numeric new_multiplier' do
      result = calculator.send(:smooth_and_limit_multiplier, "invalid")
      expect(result).to eq(1.0)
    end

    it 'updates product last_demand_multiplier' do
      expect { calculator.send(:smooth_and_limit_multiplier, 1.10) }
        .to change { product.reload.last_demand_multiplier }.to(1.10)
    end
  end

  describe 'integration test with real data flow' do
    let(:current_stats) { { purchases: 20, cart_additions: 15, total: 35 } }
    let(:previous_stats) { { purchases: 10, cart_additions: 10, total: 20 } }

    before do
      product.update!(dynamic_price: 2000)  # Medium price range
      product.update!(last_demand_multiplier: 1.0)

      allow(calculator).to receive(:get_weekly_demand_stats)
        .with(current_week_start).and_return(current_stats)
      allow(calculator).to receive(:get_weekly_demand_stats)
        .with(previous_week_start).and_return(previous_stats)
    end

    it 'processes the complete calculation flow' do
      result = calculator.calculate_multiplier

      # Verify the calculation chain:
      # Growth: purchases=100%, cart_additions=50%, total=75%
      # Weighted (0.7*100 + 0.3*50): 70 + 15 = 85%
      # Medium tier for 85% growth should return 1.35
      # Smoothed to max 15% increase: 1.15
      expect(result).to eq(1.15)
      expect(product.reload.last_demand_multiplier).to eq(1.15)
    end
  end
end
