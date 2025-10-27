require 'rails_helper'

RSpec.describe DynamicPricing::CompetitorAnalyzer, type: :service do
  let(:product) do
    Product.create!(
      name: 'Test Product',
      category: 'Electronics',
      default_price: 1500,
      dynamic_price: 1500,
      quantity: 100
    )
  end
  let(:analyzer) { described_class.new(product) }

  describe '#initialize' do
    it 'sets the product attribute' do
      expect(analyzer.product).to eq(product)
    end
  end

  describe '#analyze_and_adjust' do
    let(:our_price) { 2000 }
    let(:adjustment) { { type: :reduce, amount: 1800, reason: "competitor_undercut" } }

    before do
      allow(analyzer).to receive(:calculate_competitor_adjustment).with(our_price).and_return(adjustment)
      allow(analyzer).to receive(:apply_competitor_adjustment).with(our_price, adjustment).and_return(1800)
    end

    it 'calculates competitor adjustment and applies it' do
      result = analyzer.analyze_and_adjust(our_price)

      expect(analyzer).to have_received(:calculate_competitor_adjustment).with(our_price)
      expect(analyzer).to have_received(:apply_competitor_adjustment).with(our_price, adjustment)
      expect(result).to eq(1800)
    end
  end

  describe '#calculate_competitor_adjustment' do
    let(:our_price) { 2000 }

    context 'when competitor data is not available' do
      before do
        allow(CompetitorPricingApiClient).to receive(:fetch_prices).and_return(nil)
      end

      it 'returns no adjustment' do
        result = analyzer.send(:calculate_competitor_adjustment, our_price)
        expect(result).to eq({ type: :none, amount: 0 })
      end
    end

    context 'when competitor data is available' do
      let(:competitor_data) do
        [
          { "name" => "Other Product", "price" => 1500 },
          { "name" => "Test Product", "price" => competitor_price },
          { "name" => "Another Product", "price" => 3000 }
        ]
      end

      before do
        allow(CompetitorPricingApiClient).to receive(:fetch_prices).and_return(competitor_data)
      end

      context 'when matching product is not found' do
        let(:competitor_data) do
          [
            { "name" => "Other Product", "price" => 1500 },
            { "name" => "Different Product", "price" => 2000 }
          ]
        end

        it 'returns no adjustment' do
          result = analyzer.send(:calculate_competitor_adjustment, our_price)
          expect(result).to eq({ type: :none, amount: 0 })
        end
      end

      context 'when competitor price is invalid' do
        let(:competitor_price) { nil }

        it 'returns no adjustment for nil price' do
          result = analyzer.send(:calculate_competitor_adjustment, our_price)
          expect(result).to eq({ type: :none, amount: 0 })
        end
      end

      context 'when competitor price is zero or negative' do
        let(:competitor_price) { 0 }

        it 'returns no adjustment' do
          result = analyzer.send(:calculate_competitor_adjustment, our_price)
          expect(result).to eq({ type: :none, amount: 0 })
        end
      end

      context 'when our price is significantly higher (>10% difference)' do
        let(:competitor_price) { 1500 }  # our_price = 2000, difference = 33.33%

        it 'returns reduction adjustment' do
          result = analyzer.send(:calculate_competitor_adjustment, our_price)
          expect(result[:type]).to eq(:reduce)
          expect(result[:amount]).to eq(competitor_price)
          expect(result[:reason]).to eq("competitor_undercut")
          expect(result[:percentage]).to eq(33.33)
        end
      end

      context 'when our price is significantly lower (<-5% difference)' do
        let(:competitor_price) { 2500 }  # our_price = 2000, difference = -20%

        it 'returns increase adjustment' do
          result = analyzer.send(:calculate_competitor_adjustment, our_price)
          expect(result[:type]).to eq(:increase)
          expect(result[:amount]).to eq([ our_price * 1.05, competitor_price * 0.95 ].min.to_i)
          expect(result[:reason]).to eq("competitor_premium")
          expect(result[:percentage]).to eq(-20.0)
        end
      end

      context 'when price difference is within competitive range (-5% to 10%)' do
        let(:competitor_price) { 1900 }  # our_price = 2000, difference = 5.26%

        it 'returns no adjustment' do
          result = analyzer.send(:calculate_competitor_adjustment, our_price)
          expect(result[:type]).to eq(:none)
          expect(result[:amount]).to eq(0)
          expect(result[:reason]).to eq("competitive_range")
          expect(result[:percentage]).to eq(5.26)
        end
      end

      context 'with case-insensitive product name matching' do
        let(:product) { Product.create!(name: 'TEST PRODUCT', category: 'Electronics', default_price: 1500, dynamic_price: 1500, quantity: 100) }
        let(:competitor_data) do
          [ { "name" => "test product", "price" => 1500 } ]
        end

        it 'matches products regardless of case' do
          result = analyzer.send(:calculate_competitor_adjustment, our_price)
          expect(result[:type]).to eq(:reduce)
        end
      end
    end
  end

  describe '#apply_competitor_adjustment' do
    let(:calculated_price) { 2000 }

    context 'when adjustment type is reduce' do
      let(:adjustment) { { type: :reduce, amount: 1500 } }

      it 'returns the adjustment amount but not less than 80% of calculated price' do
        result = analyzer.send(:apply_competitor_adjustment, calculated_price, adjustment)
        expect(result).to eq(1600)  # max(1500, 2000 * 0.8) = max(1500, 1600) = 1600
      end

      context 'when adjustment amount is higher than 80% floor' do
        let(:adjustment) { { type: :reduce, amount: 1800 } }

        it 'returns the adjustment amount' do
          result = analyzer.send(:apply_competitor_adjustment, calculated_price, adjustment)
          expect(result).to eq(1800)
        end
      end
    end

    context 'when adjustment type is increase' do
      let(:adjustment) { { type: :increase, amount: 2200 } }

      it 'returns the adjustment amount' do
        result = analyzer.send(:apply_competitor_adjustment, calculated_price, adjustment)
        expect(result).to eq(2200)
      end
    end

    context 'when adjustment type is none' do
      let(:adjustment) { { type: :none, amount: 0 } }

      it 'returns the original calculated price' do
        result = analyzer.send(:apply_competitor_adjustment, calculated_price, adjustment)
        expect(result).to eq(calculated_price)
      end
    end

    context 'when adjustment type is unrecognized' do
      let(:adjustment) { { type: :unknown, amount: 1500 } }

      it 'returns the original calculated price' do
        result = analyzer.send(:apply_competitor_adjustment, calculated_price, adjustment)
        expect(result).to eq(calculated_price)
      end
    end
  end

  describe 'integration test with real data flow' do
    let(:our_price) { 2000 }
    let(:competitor_data) do
      [
        { "name" => "Test Product", "price" => 1500 },
        { "name" => "Other Product", "price" => 3000 }
      ]
    end

    before do
      allow(CompetitorPricingApiClient).to receive(:fetch_prices).and_return(competitor_data)
    end

    it 'processes the complete analysis and adjustment flow' do
      result = analyzer.analyze_and_adjust(our_price)

      # Our price (2000) vs competitor (1500) = 33.33% difference
      # Should trigger reduction to competitor price (1500)
      # But apply 80% floor: max(1500, 2000 * 0.8) = max(1500, 1600) = 1600
      expect(result).to eq(1600)
    end

    context 'when competitor price would result in increase' do
      let(:competitor_data) do
        [ { "name" => "Test Product", "price" => 2500 } ]
      end

      it 'applies increase adjustment correctly' do
        result = analyzer.analyze_and_adjust(our_price)

        # Our price (2000) vs competitor (2500) = -20% difference
        # Should trigger increase to min(2000 * 1.05, 2500 * 0.95) = min(2100, 2375) = 2100
        expect(result).to eq(2100)
      end
    end

    context 'when price is in competitive range' do
      let(:competitor_data) do
        [ { "name" => "Test Product", "price" => 1900 } ]
      end

      it 'returns original price unchanged' do
        result = analyzer.analyze_and_adjust(our_price)
        expect(result).to eq(our_price)
      end
    end
  end
end
