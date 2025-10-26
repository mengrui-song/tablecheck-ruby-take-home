require 'rails_helper'

RSpec.describe Order, type: :model do
  describe 'validations' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }

    it 'is valid with valid attributes' do
      order = Order.new(user: user, total_price: 100.0)
      expect(order).to be_valid
    end

    it 'has a default status of pending' do
      order = Order.new(user: user)
      expect(order.status).to eq('pending')
    end

    it 'validates status inclusion' do
      order = Order.new(user: user, status: 'invalid_status')
      expect(order).not_to be_valid
      expect(order.errors[:status]).to include('is not included in the list')
    end

    it 'allows pending status' do
      order = Order.new(user: user, status: 'pending')
      expect(order).to be_valid
    end

    it 'allows paid status' do
      order = Order.new(user: user, status: 'paid')
      expect(order).to be_valid
    end
  end

  describe 'associations' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }
    let(:order) { Order.create!(user: user) }

    it 'belongs to user' do
      expect(order).to respond_to(:user)
      expect(order.user).to eq(user)
    end

    it 'has many order_items' do
      expect(order).to respond_to(:order_items)

      product = Product.create!(name: 'Test Product', category: 'Test', default_price: 100, quantity: 50)
      order_item = order.order_items.create!(product: product, quantity: 2, price: 100)

      expect(order.order_items).to include(order_item)
    end
  end

  describe 'attributes' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }

    it 'allows setting and getting status' do
      order = Order.new(user: user)
      order.status = 'paid'
      expect(order.status).to eq('paid')
    end

    it 'allows setting and getting total_price' do
      order = Order.new(user: user)
      order.total_price = 250.50
      expect(order.total_price).to eq(250.50)
    end
  end

  describe '#place!' do
    let(:product) { Product.create!(name: 'Test Product', category: 'Test', default_price: 100, quantity: 10) }
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }
    let(:cart) { Cart.create(user: user) }
    let(:order) { user.orders.new }

    before do
      cart.add_product(product.id.to_s, 2)
    end

    it 'successfully places an order' do
      expect { order.place!(cart) }.not_to raise_error

      order.reload
      expect(order.status).to eq('paid')
      expect(order.total_price).to eq(200.0)
      expect(order.order_items.count).to eq(1)
    end

    it 'creates order items with correct attributes' do
      order.place!(cart)

      order_item = order.order_items.first
      expect(order_item.product).to eq(product)
      expect(order_item.quantity).to eq(2)
      expect(order_item.price).to eq(100)
    end

    it 'reduces product inventory' do
      initial_quantity = product.quantity
      order.place!(cart)

      product.reload
      expect(product.quantity).to eq(initial_quantity - 2)
    end

    it 'calculates total price correctly' do
      order.place!(cart)

      expect(order.total_price).to eq(2 * product.default_price)
    end

    it 'clears the cart after placing order' do
      order.place!(cart)

      cart.reload
      expect(cart.cart_items.count).to eq(0)
    end

    it 'raise error if user has product in cart when product quantity is updated' do
      product.update!(quantity: 1)

      expect { order.place!(cart) }.to raise_error("Not enough inventory for #{product.name}")

      product.reload
      expect(product.quantity).to eq(1) # Inventory should remain unchanged
    end

    it 'handles multiple products in cart' do
      product2 = Product.create!(name: 'Product 2', category: 'Test', default_price: 50, quantity: 5)
      cart.add_product(product2.id.to_s, 1)

      order.place!(cart)

      expect(order.order_items.count).to eq(2)
      expect(order.total_price).to eq(250.0) # (2 * 100) + (1 * 50)
    end

    it 'starts with pending status then changes to paid' do
      order.place!(cart)

      expect(order.status).to eq('paid')
    end

    it 'preserves price at order time' do
      order.place!(cart)

      # Change product price after order
      product.update!(default_price: 200)

      order_item = order.order_items.first
      expect(order_item.price).to eq(100) # Original price preserved
    end
  end
end
