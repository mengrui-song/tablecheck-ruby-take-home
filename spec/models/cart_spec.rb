require 'rails_helper'

RSpec.describe Cart, type: :model do
  describe 'validations' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }

    it 'is valid with valid attributes' do
      cart = Cart.new(user: user)
      expect(cart).to be_valid
    end

    it 'requires user association' do
      cart = Cart.new
      expect(cart).not_to be_valid
    end
  end

  describe 'associations' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }
    let(:cart) { Cart.create!(user: user) }
    let(:product) { Product.create!(name: 'Test Product', category: 'Test', default_price: 100, quantity: 50) }

    it 'belongs to user' do
      expect(cart).to respond_to(:user)
      expect(cart.user).to eq(user)
    end

    it 'has many cart_items' do
      expect(cart).to respond_to(:cart_items)

      cart_item = cart.cart_items.create!(product: product, quantity: 2)
      expect(cart.cart_items).to include(cart_item)
    end

    it 'destroys dependent cart_items when cart is destroyed' do
      cart_item = cart.cart_items.create!(product: product, quantity: 2)
      cart_item_id = cart_item.id

      cart.destroy
      expect(CartItem.where(id: cart_item_id)).to be_empty
    end
  end

  describe '#add_product' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }
    let(:cart) { Cart.create!(user: user) }
    let(:product) { Product.create!(name: 'Test Product', category: 'Test', default_price: 100, quantity: 50) }

    it 'adds a new product to the cart' do
      expect { cart.add_product(product.id, 2) }.to change { cart.distinct_products_count }.by(1)

      cart_item = cart.cart_items.first
      expect(cart_item.product).to eq(product)
      expect(cart_item.quantity).to eq(2)
    end

    it 'defaults quantity to 1 when not specified' do
      cart.add_product(product.id)

      cart_item = cart.cart_items.first
      expect(cart_item.quantity).to eq(1)
    end

    it 'increases quantity for existing product' do
      cart.add_product(product.id, 2)
      cart.add_product(product.id, 3)

      expect(cart.distinct_products_count).to eq(1)
      cart_item = cart.cart_items.first
      expect(cart_item.quantity).to eq(5)
    end

    it 'handles multiple different products' do
      product2 = Product.create!(name: 'Test Product 2', category: 'Test', default_price: 200, quantity: 30)

      cart.add_product(product.id, 2)
      cart.add_product(product2.id, 1)

      expect(cart.distinct_products_count).to eq(2)
      expect(cart.cart_items.map(&:product)).to contain_exactly(product, product2)
    end

    it 'handles zero quantity addition' do
      expect { cart.add_product(product.id, 0) }.to raise_error(ArgumentError, "Quantity must be greater than 0")
    end

    it 'handles negative quantity addition' do
      expect { cart.add_product(product.id, -1) }.to raise_error(ArgumentError, "Quantity must be greater than 0")
    end

    it 'handles invalid product_id' do
      invalid_id = BSON::ObjectId.new
      expect { cart.add_product(invalid_id, 2) }.to raise_error(ArgumentError, "Product with id #{invalid_id} does not exist")
    end
  end

  describe '#total_price' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }
    let(:cart) { Cart.create!(user: user) }
    let(:product1) { Product.create!(name: 'Product 1', category: 'Test', default_price: 100, quantity: 50) }
    let(:product2) { Product.create!(name: 'Product 2', category: 'Test', default_price: 250, quantity: 30) }

    it 'calculates total price for empty cart' do
      expect(cart.total_price).to eq(0)
    end

    it 'calculates total price for single item' do
      cart.cart_items.create!(product: product1, quantity: 2)
      expect(cart.total_price).to eq(200)
    end

    it 'calculates total price for multiple items' do
      cart.cart_items.create!(product: product1, quantity: 2)
      cart.cart_items.create!(product: product2, quantity: 1)
      # product1: 100 * 2 + product2: 250 * 1 = 450
      expect(cart.total_price).to eq(450)
    end

    it 'handles cart items with nil product gracefully' do
      cart.cart_items.create!(product: product1, quantity: 2)

      # Create a cart item without a product to test the nil check
      cart_item = cart.cart_items.build(quantity: 3)
      cart_item.save(validate: false)

      expect(cart.total_price).to eq(200)
    end

    it 'calculates correct total with different quantities and prices' do
      expensive_product = Product.create!(name: 'Expensive Product', category: 'Luxury', default_price: 1000, quantity: 10)

      cart.cart_items.create!(product: product1, quantity: 3)
      cart.cart_items.create!(product: product2, quantity: 2)
      cart.cart_items.create!(product: expensive_product, quantity: 1)

      expected_total = (100 * 3) + (250 * 2) + (1000 * 1)
      expect(cart.total_price).to eq(expected_total)
    end

    it 'handles zero price products in total calculation' do
      free_product = Product.create!(name: 'Free Product', category: 'Free', default_price: 0, quantity: 10)
      cart.cart_items.create!(product: product1, quantity: 2)
      cart.cart_items.create!(product: free_product, quantity: 5)
      expect(cart.total_price).to eq(200)
    end

    it 'handles large quantities and prices' do
      expensive_product = Product.create!(name: 'Very Expensive', category: 'Luxury', default_price: 10000, quantity: 1)
      cart.cart_items.create!(product: expensive_product, quantity: 100)
      expect(cart.total_price).to eq(1000000)
    end
  end

  describe 'helper methods' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }
    let(:cart) { Cart.create!(user: user) }
    let(:product1) { Product.create!(name: 'Product 1', category: 'Test', default_price: 100, quantity: 50) }
    let(:product2) { Product.create!(name: 'Product 2', category: 'Test', default_price: 200, quantity: 30) }

    describe '#distinct_products_count' do
      it 'returns number of different products in cart' do
        expect(cart.distinct_products_count).to eq(0)

        cart.add_product(product1.id, 3)
        expect(cart.distinct_products_count).to eq(1)

        cart.add_product(product2.id, 2)
        expect(cart.distinct_products_count).to eq(2)

        cart.add_product(product1.id, 1) # Adding more of existing product
        expect(cart.distinct_products_count).to eq(2)
      end
    end

    describe '#total_items_count' do
      it 'returns total quantity of all items in cart' do
        expect(cart.total_items_count).to eq(0)

        cart.add_product(product1.id, 3)
        expect(cart.total_items_count).to eq(3)

        cart.add_product(product2.id, 2)
        expect(cart.total_items_count).to eq(5)

        cart.add_product(product1.id, 1) # Adding more of existing product
        expect(cart.total_items_count).to eq(6)
      end
    end

    describe '#empty?' do
      it 'returns true for empty cart' do
        expect(cart.empty?).to be true
      end

      it 'returns false for cart with items' do
        cart.add_product(product1.id, 1)
        expect(cart.empty?).to be false
      end
    end
  end

  describe 'attributes' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }

    it 'stores timestamps' do
      cart = Cart.create!(user: user)
      expect(cart.created_at).to be_present
      expect(cart.updated_at).to be_present
    end
  end
end
