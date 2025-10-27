require 'rails_helper'

RSpec.describe DynamicPricing::InventoryCalculator, type: :service do
  let(:product) do
    Product.create!(
      name: 'Test Product',
      category: 'Footwear',
      default_price: 1500,
      dynamic_price: 1500,
      quantity: 100,
      last_demand_multiplier: 1.0
    )
  end
  let(:calculator) { described_class.new(product) }

  describe '#calculate_multiplier' do
    context 'when product quantity is zero' do
      before { product.update!(quantity: 0) }

      it 'returns 1.0' do
        expect(calculator.calculate_multiplier).to eq(1.0)
      end
    end

    context 'with very low stock (1-50)' do
      before { product.update!(quantity: 25) }

      it 'returns base multiplier of 1.3 for Footwear' do
        # 1.3 (very low stock) * 1.05 (footwear) = 1.365 -> 1.37 (rounded)
        expect(calculator.calculate_multiplier).to eq(1.37)
      end

      context 'for different categories' do
        it 'applies Footwear premium (1.05)' do
          product.update!(category: 'Footwear')
          expect(calculator.calculate_multiplier).to eq(1.37) # 1.3 * 1.05 = 1.365 -> 1.37
        end

        it 'applies Accessories discount (0.95)' do
          product.update!(category: 'Accessories')
          expect(calculator.calculate_multiplier).to eq(1.24) # 1.3 * 0.95 = 1.235 -> 1.24
        end

        it 'applies Clothing baseline (1.0)' do
          product.update!(category: 'Clothing')
          expect(calculator.calculate_multiplier).to eq(1.3) # 1.3 * 1.0
        end
      end
    end

    context 'with low stock (51-100)' do
      before { product.update!(quantity: 75) }

      it 'returns base multiplier of 1.2' do
        expect(calculator.calculate_multiplier).to eq(1.26) # 1.2 * 1.05 = 1.26
      end
    end

    context 'with medium-low stock (101-175)' do
      before { product.update!(quantity: 150) }

      it 'returns base multiplier of 1.1' do
        expect(calculator.calculate_multiplier).to eq(1.16) # 1.1 * 1.05 = 1.155 -> 1.16
      end
    end

    context 'with good stock (176-250)' do
      before { product.update!(quantity: 200) }

      it 'returns base multiplier of 1.0' do
        expect(calculator.calculate_multiplier).to eq(1.05) # 1.0 * 1.05 = 1.05
      end
    end

    context 'with high stock (251+)' do
      before { product.update!(quantity: 280) }

      it 'returns base multiplier of 0.9' do
        expect(calculator.calculate_multiplier).to eq(0.95) # 0.9 * 1.05 = 0.945 -> 0.95
      end
    end
  end

  describe '#quantity_multiplier' do
    it 'returns 1.3 for quantity 1-50' do
      product.update!(quantity: 1)
      expect(calculator.send(:quantity_multiplier)).to eq(1.3)

      product.update!(quantity: 50)
      expect(calculator.send(:quantity_multiplier)).to eq(1.3)
    end

    it 'returns 1.2 for quantity 51-100' do
      product.update!(quantity: 51)
      expect(calculator.send(:quantity_multiplier)).to eq(1.2)

      product.update!(quantity: 100)
      expect(calculator.send(:quantity_multiplier)).to eq(1.2)
    end

    it 'returns 1.1 for quantity 101-175' do
      product.update!(quantity: 101)
      expect(calculator.send(:quantity_multiplier)).to eq(1.1)

      product.update!(quantity: 175)
      expect(calculator.send(:quantity_multiplier)).to eq(1.1)
    end

    it 'returns 1.0 for quantity 176-250' do
      product.update!(quantity: 176)
      expect(calculator.send(:quantity_multiplier)).to eq(1.0)

      product.update!(quantity: 250)
      expect(calculator.send(:quantity_multiplier)).to eq(1.0)
    end

    it 'returns 0.9 for quantity above 250' do
      product.update!(quantity: 251)
      expect(calculator.send(:quantity_multiplier)).to eq(0.9)

      product.update!(quantity: 500)
      expect(calculator.send(:quantity_multiplier)).to eq(0.9)
    end
  end

  describe '#category_adjustment' do
    it 'returns 1.05 for Footwear category' do
      product.update!(category: 'Footwear')
      expect(calculator.send(:category_adjustment)).to eq(1.05)
    end

    it 'returns 1.05 for footwear category (case insensitive)' do
      product.update!(category: 'footwear')
      expect(calculator.send(:category_adjustment)).to eq(1.05)
    end

    it 'returns 0.95 for Accessories category' do
      product.update!(category: 'Accessories')
      expect(calculator.send(:category_adjustment)).to eq(0.95)
    end

    it 'returns 0.95 for accessories category (case insensitive)' do
      product.update!(category: 'accessories')
      expect(calculator.send(:category_adjustment)).to eq(0.95)
    end

    it 'returns 1.0 for Clothing category' do
      product.update!(category: 'Clothing')
      expect(calculator.send(:category_adjustment)).to eq(1.0)
    end

    it 'returns 1.0 for clothing category (case insensitive)' do
      product.update!(category: 'clothing')
      expect(calculator.send(:category_adjustment)).to eq(1.0)
    end

    it 'returns 1.0 for unknown category' do
      product.update!(category: 'Electronics')
      expect(calculator.send(:category_adjustment)).to eq(1.0)
    end
  end

  describe 'integration test with actual inventory data' do
    context 'with real inventory examples' do
      it 'handles A-Team Headband (lowest quantity: 23, Accessories)' do
        product.update!(quantity: 23, category: 'Accessories')
        # Very low stock (1.3) * Accessories (0.95) = 1.235 -> 1.24
        expect(calculator.calculate_multiplier).to eq(1.24)
      end

      it 'handles Michael Jackson Glove (highest quantity: 292, Accessories)' do
        product.update!(quantity: 292, category: 'Accessories')
        # High stock (0.9) * Accessories (0.95) = 0.855 -> 0.86
        expect(calculator.calculate_multiplier).to eq(0.86)
      end

      it 'handles Ghostbusters T-Shirt (medium quantity: 141, Clothing)' do
        product.update!(quantity: 141, category: 'Clothing')
        # Medium-low stock (1.1) * Clothing (1.0) = 1.1
        expect(calculator.calculate_multiplier).to eq(1.1)
      end

      it 'handles MC Hammer Pants (high quantity: 285, Footwear)' do
        product.update!(quantity: 285, category: 'Footwear')
        # High stock (0.9) * Footwear (1.05) = 0.945 -> 0.95
        expect(calculator.calculate_multiplier).to eq(0.95)
      end
    end
  end

  describe 'boundary testing' do
    context 'at quantity thresholds' do
      it 'handles boundary between very low and low stock (50->51)' do
        product.update!(quantity: 50, category: 'Clothing')
        expect(calculator.calculate_multiplier).to eq(1.3)

        product.update!(quantity: 51, category: 'Clothing')
        expect(calculator.calculate_multiplier).to eq(1.2)
      end

      it 'handles boundary between low and medium-low stock (100->101)' do
        product.update!(quantity: 100, category: 'Clothing')
        expect(calculator.calculate_multiplier).to eq(1.2)

        product.update!(quantity: 101, category: 'Clothing')
        expect(calculator.calculate_multiplier).to eq(1.1)
      end

      it 'handles boundary between medium-low and good stock (175->176)' do
        product.update!(quantity: 175, category: 'Clothing')
        expect(calculator.calculate_multiplier).to eq(1.1)

        product.update!(quantity: 176, category: 'Clothing')
        expect(calculator.calculate_multiplier).to eq(1.0)
      end

      it 'handles boundary between good and high stock (250->251)' do
        product.update!(quantity: 250, category: 'Clothing')
        expect(calculator.calculate_multiplier).to eq(1.0)

        product.update!(quantity: 251, category: 'Clothing')
        expect(calculator.calculate_multiplier).to eq(0.9)
      end
    end
  end

  describe 'edge cases' do
    it 'handles very large quantities' do
      product.update!(quantity: 10000, category: 'Clothing')
      expect(calculator.calculate_multiplier).to eq(0.9)
    end

    it 'handles minimum quantity (1)' do
      product.update!(quantity: 1, category: 'Clothing')
      expect(calculator.calculate_multiplier).to eq(1.3)
    end
  end
end
