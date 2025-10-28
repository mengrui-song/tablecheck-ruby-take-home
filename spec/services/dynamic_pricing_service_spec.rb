require 'rails_helper'

RSpec.describe DynamicPricingService, type: :service do
  let(:product) do
    Product.create!(
      name: 'Test Product',
      category: 'Electronics',
      default_price: 1000,
      dynamic_price: 1000,
      quantity: 50,
      last_demand_multiplier: 1.0
    )
  end
  let(:service) { described_class.new(product) }
  let(:demand_calculator) { instance_double(DynamicPricing::DemandCalculator) }
  let(:inventory_calculator) { instance_double(DynamicPricing::InventoryCalculator) }
  let(:competitor_analyzer) { instance_double(DynamicPricing::CompetitorAnalyzer) }

  before do
    allow(DynamicPricing::DemandCalculator).to receive(:new).with(product).and_return(demand_calculator)
    allow(DynamicPricing::InventoryCalculator).to receive(:new).with(product).and_return(inventory_calculator)
    allow(DynamicPricing::CompetitorAnalyzer).to receive(:new).with(product).and_return(competitor_analyzer)
  end

  describe '#calculate_dynamic_price' do
    describe 'Story: The Popular Gadget Launch 📱' do
      context 'high demand + low inventory + competitors pricing higher' do
        before do
          allow(demand_calculator).to receive(:calculate_multiplier).and_return(1.3)
          allow(inventory_calculator).to receive(:calculate_multiplier).and_return(1.4)
          allow(competitor_analyzer).to receive(:analyze_and_adjust).and_return(1900)
        end

        it 'increases price significantly due to scarcity and demand' do
          result = service.calculate_dynamic_price
          expect(result).to eq(1900)
          expect(product.reload.dynamic_price).to eq(1900)
        end

        it 'calls calculators in correct sequence' do
          service.calculate_dynamic_price
          expect(competitor_analyzer).to have_received(:analyze_and_adjust).with(1820) # 1000 * 1.3 * 1.4
        end
      end
    end

    describe 'Story: The Overstocked Books 📚' do
      context 'low demand + high inventory + competitors undercutting' do
        before do
          allow(demand_calculator).to receive(:calculate_multiplier).and_return(0.8)
          allow(inventory_calculator).to receive(:calculate_multiplier).and_return(0.8)
          allow(competitor_analyzer).to receive(:analyze_and_adjust).and_return(600)
        end

        it 'protects against going below 80% price floor' do
          result = service.calculate_dynamic_price
          expect(result).to eq(800) # 80% of 1000
          expect(product.reload.dynamic_price).to eq(800)
        end

        it 'receives calculated price before competitor adjustment' do
          service.calculate_dynamic_price
          expect(competitor_analyzer).to have_received(:analyze_and_adjust).with(640) # 1000 * 0.8 * 0.8
        end
      end
    end

    describe 'Story: The Seasonal Clothing Clearance 👕' do
      context 'moderate demand + high inventory + competitive market' do
        before do
          allow(demand_calculator).to receive(:calculate_multiplier).and_return(1.1)
          allow(inventory_calculator).to receive(:calculate_multiplier).and_return(0.9)
          allow(competitor_analyzer).to receive(:analyze_and_adjust).and_return(950)
        end

        it 'balances all factors for moderate price adjustment' do
          result = service.calculate_dynamic_price
          expect(result).to eq(950)
        end

        it 'calculates base price correctly before competitor analysis' do
          service.calculate_dynamic_price
          expect(competitor_analyzer).to have_received(:analyze_and_adjust).with(990) # 1000 * 1.1 * 0.9
        end
      end
    end

    describe 'Story: The Luxury Item Dilemma 🏠' do
      context 'low demand + low inventory (scarcity premium vs demand concerns)' do
        before do
          allow(demand_calculator).to receive(:calculate_multiplier).and_return(0.9)
          allow(inventory_calculator).to receive(:calculate_multiplier).and_return(1.3)
          allow(competitor_analyzer).to receive(:analyze_and_adjust).and_return(1150)
        end

        it 'applies scarcity premium despite lower demand' do
          result = service.calculate_dynamic_price
          expect(result).to eq(1150)
        end

        it 'balances conflicting demand and inventory signals' do
          service.calculate_dynamic_price
          expect(competitor_analyzer).to have_received(:analyze_and_adjust).with(1170) # 1000 * 0.9 * 1.3
        end
      end
    end

    describe 'Story: The Market Leader Position ⚡' do
      context 'high demand + optimal inventory + competitive advantage' do
        before do
          allow(demand_calculator).to receive(:calculate_multiplier).and_return(1.2)
          allow(inventory_calculator).to receive(:calculate_multiplier).and_return(1.0)
          allow(competitor_analyzer).to receive(:analyze_and_adjust).and_return(1300)
        end

        it 'maximizes profit when conditions align' do
          result = service.calculate_dynamic_price
          expect(result).to eq(1300)
        end

        it 'leverages strong demand for premium pricing' do
          service.calculate_dynamic_price
          expect(competitor_analyzer).to have_received(:analyze_and_adjust).with(1200) # 1000 * 1.2 * 1.0
        end
      end
    end

    describe 'Edge Cases and Business Rules' do
      context 'with neutral multipliers (baseline scenario)' do
        before do
          allow(demand_calculator).to receive(:calculate_multiplier).and_return(1.0)
          allow(inventory_calculator).to receive(:calculate_multiplier).and_return(1.0)
          allow(competitor_analyzer).to receive(:analyze_and_adjust).and_return(1000)
        end

        it 'maintains original price with neutral conditions' do
          result = service.calculate_dynamic_price
          expect(result).to eq(1000)
        end
      end

      context 'extreme downward pressure scenario' do
        before do
          allow(demand_calculator).to receive(:calculate_multiplier).and_return(0.7)
          allow(inventory_calculator).to receive(:calculate_multiplier).and_return(0.7)
          allow(competitor_analyzer).to receive(:analyze_and_adjust).and_return(400)
        end

        it 'enforces 80% minimum price floor even with extreme conditions' do
          result = service.calculate_dynamic_price
          expect(result).to eq(800) # 80% of 1000
        end
      end

      context 'when competitor adjustment exceeds calculation but below floor' do
        before do
          allow(demand_calculator).to receive(:calculate_multiplier).and_return(0.8)
          allow(inventory_calculator).to receive(:calculate_multiplier).and_return(0.9)
          allow(competitor_analyzer).to receive(:analyze_and_adjust).and_return(700)
        end

        it 'respects price floor over competitor adjustment' do
          result = service.calculate_dynamic_price
          expect(result).to eq(800)
        end
      end

      context 'with very high multipliers' do
        before do
          allow(demand_calculator).to receive(:calculate_multiplier).and_return(1.5)
          allow(inventory_calculator).to receive(:calculate_multiplier).and_return(1.4)
          allow(competitor_analyzer).to receive(:analyze_and_adjust).and_return(2100)
        end

        it 'allows significant price increases when justified' do
          result = service.calculate_dynamic_price
          expect(result).to eq(2100)
        end
      end
    end

    describe 'Calculation Flow Verification' do
      it 'follows the correct calculation sequence' do
        allow(demand_calculator).to receive(:calculate_multiplier).and_return(1.1)
        allow(inventory_calculator).to receive(:calculate_multiplier).and_return(1.2)
        allow(competitor_analyzer).to receive(:analyze_and_adjust).with(1320).and_return(1280)

        result = service.calculate_dynamic_price

        expect(demand_calculator).to have_received(:calculate_multiplier).ordered
        expect(inventory_calculator).to have_received(:calculate_multiplier).ordered
        expect(competitor_analyzer).to have_received(:analyze_and_adjust).with(1320).ordered
        expect(result).to eq(1280)
      end

      it 'updates product dynamic_price correctly' do
        allow(demand_calculator).to receive(:calculate_multiplier).and_return(1.05)
        allow(inventory_calculator).to receive(:calculate_multiplier).and_return(1.05)
        allow(competitor_analyzer).to receive(:analyze_and_adjust).and_return(1100)

        expect { service.calculate_dynamic_price }
          .to change { product.reload.dynamic_price }.from(1000).to(1100)
      end
    end
  end
end

# Integration tests with real calculator logic
RSpec.describe DynamicPricingService, 'Integration Tests', type: :service do
  describe '.update_all_prices' do
    let!(:gadget) do
      Product.create!(
        name: 'Popular Gadget',
        category: 'Electronics',
        default_price: 500,
        dynamic_price: 500,
        quantity: 5,
        last_demand_multiplier: 1.0
      )
    end

    let!(:book) do
      Product.create!(
        name: 'Overstocked Book',
        category: 'Books',
        default_price: 800,
        dynamic_price: 800,
        quantity: 100,
        last_demand_multiplier: 1.0
      )
    end

    let!(:clothing) do
      Product.create!(
        name: 'Seasonal Clothing',
        category: 'Clothing',
        default_price: 1200,
        dynamic_price: 1200,
        quantity: 30,
        last_demand_multiplier: 1.0
      )
    end

    before do
      # Mock only the external dependencies to control the test environment
      allow_any_instance_of(DynamicPricing::DemandCalculator).to receive(:calculate_multiplier)
        .and_return(1.0) # Low volume = 1.0 multiplier

      # Mock HTTP requests for competitor pricing
      allow(CompetitorPricingApiClient).to receive(:fetch_prices)
        .and_return([
          {
            "name": "Popular Gadget",
            "category": "Electronics",
            "price": 8968,
            "qty": 169
          },
          {
            "name": "Overstocked Book",
            "category": "Books",
            "price": 8968,
            "qty": 169
          },
          {
            "name": "Seasonal Clothing",
            "category": "Clothing",
            "price": 8968,
            "qty": 169
          }
        ])
    end

    it 'updates prices for all products using real calculation logic' do
      described_class.update_all_prices

      gadget.reload
      book.reload
      clothing.reload

      # Verify prices were calculated using real logic:
      # - Demand: 1.0 (low transaction volume)
      # - Inventory: calculated based on quantity levels
      # - Competitor: high competitor prices (8968) - no reduction needed
      # - Floor: 80% protection applied

      # Low inventory (5) should increase price: 500 * 1.0 * 1.3 = 650
      expect(gadget.dynamic_price).to eq(650)

      # Low inventory (100) should increase price: 800 * 1.0 * 1.2 = 960
      expect(book.dynamic_price).to eq(960)

      # Very low inventory (30) should increase price: 1200 * 1.0 * 1.3 = 1560
      expect(clothing.dynamic_price).to eq(1560)

      # All prices respect the 80% floor
      expect(gadget.dynamic_price).to be >= 400    # 80% of 500
      expect(book.dynamic_price).to be >= 640      # 80% of 800
      expect(clothing.dynamic_price).to be >= 960  # 80% of 1200
    end

    context 'when individual product update fails' do
      before do
        allow(Rails.logger).to receive(:error)
        allow(gadget).to receive(:update).and_raise(StandardError.new("Database connection lost"))
        allow(Product).to receive(:all).and_return([ gadget, book, clothing ])
      end

      it 'logs error and continues processing remaining products' do
        expect { described_class.update_all_prices }.not_to raise_error

        expect(Rails.logger).to have_received(:error)
          .with("Failed to update price for product #{gadget.id}: Database connection lost")
      end
    end

    context 'when multiple products fail' do
      before do
        allow(Rails.logger).to receive(:error)
        allow_any_instance_of(Product).to receive(:update).and_raise(StandardError.new("System error"))
      end

      it 'continues processing all products despite failures' do
        expect { described_class.update_all_prices }.not_to raise_error
        expect(Rails.logger).to have_received(:error).exactly(3).times # [ 3 products: gadget, book, clothing ]
      end
    end
  end

  describe 'Private method memoization' do
    let(:product) do
      Product.create!(
        name: 'Memoization Test Product',
        category: 'Electronics',
        default_price: 1000,
        dynamic_price: 1000,
        quantity: 50,
        last_demand_multiplier: 1.0
      )
    end
    let(:service) { described_class.new(product) }

    before do
      allow(DynamicPricing::DemandCalculator).to receive(:new).and_call_original
      allow(DynamicPricing::InventoryCalculator).to receive(:new).and_call_original
      allow(DynamicPricing::CompetitorAnalyzer).to receive(:new).and_call_original
    end

    it 'memoizes demand_calculator instance' do
      calc1 = service.send(:demand_calculator)
      calc2 = service.send(:demand_calculator)
      expect(calc1).to be(calc2)
      expect(DynamicPricing::DemandCalculator).to have_received(:new).once
    end

    it 'memoizes inventory_calculator instance' do
      calc1 = service.send(:inventory_calculator)
      calc2 = service.send(:inventory_calculator)
      expect(calc1).to be(calc2)
      expect(DynamicPricing::InventoryCalculator).to have_received(:new).once
    end

    it 'memoizes competitor_analyzer instance' do
      analyzer1 = service.send(:competitor_analyzer)
      analyzer2 = service.send(:competitor_analyzer)
      expect(analyzer1).to be(analyzer2)
      expect(DynamicPricing::CompetitorAnalyzer).to have_received(:new).once
    end
  end

  describe 'Private method memoization (integration context)' do
    let(:product) do
      Product.create!(
        name: 'Integration Test Product',
        category: 'Electronics',
        default_price: 1000,
        quantity: 50,
        last_demand_multiplier: 1.0
      )
    end
    let(:service) { described_class.new(product) }

    before do
      # Mock external dependencies only
      allow_any_instance_of(DynamicPricing::DemandCalculator).to receive(:get_weekly_demand_stats)
        .and_return({ purchases: 5, cart_additions: 3, total: 8 })
      allow(CompetitorPricingApiClient).to receive(:fetch_prices).and_return([ {
        "name": "Integration Test Product",
        "category": "Electronics",
        "price": 1200,
        "qty": 274
        },
        {
        "name": "Jelly Shoes",
        "category": "Footwear",
        "price": 8968,
        "qty": 169
        } ])
    end

    it 'uses real calculator instances without mocking constructors' do
      calc1 = service.send(:demand_calculator)
      calc2 = service.send(:demand_calculator)

      expect(calc1).to be(calc2)
      expect(calc1).to be_a(DynamicPricing::DemandCalculator)
      expect(calc1).to respond_to(:calculate_multiplier)
    end
  end
end
