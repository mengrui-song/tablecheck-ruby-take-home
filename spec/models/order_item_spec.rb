require 'rails_helper'

RSpec.describe OrderItem, type: :model do
  describe 'validations' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }
    let(:order) { user.orders.create!(status: 'pending') }
    let(:product) { Product.create!(name: 'Test Product', category: 'Test', default_price: 100, quantity: 50) }

    it 'is valid with valid attributes' do
      order_item = OrderItem.new(order: order, product: product, quantity: 2, price: 100.0)
      expect(order_item).to be_valid
    end

    it 'requires quantity to be greater than 0' do
      order_item = OrderItem.new(order: order, product: product, quantity: 0, price: 100.0)
      expect(order_item).not_to be_valid
      expect(order_item.errors[:quantity]).to include('must be greater than 0')
    end

    it 'requires quantity to be greater than 0 for negative values' do
      order_item = OrderItem.new(order: order, product: product, quantity: -1, price: 100.0)
      expect(order_item).not_to be_valid
      expect(order_item.errors[:quantity]).to include('must be greater than 0')
    end

    it 'allows positive quantity' do
      order_item = OrderItem.new(order: order, product: product, quantity: 5, price: 100.0)
      expect(order_item).to be_valid
    end
  end

  describe 'associations' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }
    let(:order) { user.orders.create!(status: 'pending') }
    let(:product) { Product.create!(name: 'Test Product', category: 'Test', default_price: 100, quantity: 50) }
    let(:order_item) { OrderItem.create!(order: order, product: product, quantity: 2, price: 100.0) }

    it 'belongs to order' do
      expect(order_item).to respond_to(:order)
      expect(order_item.order).to eq(order)
    end

    it 'belongs to product' do
      expect(order_item).to respond_to(:product)
      expect(order_item.product).to eq(product)
    end
  end

  describe 'attributes' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }
    let(:order) { user.orders.create!(status: 'pending') }
    let(:product) { Product.create!(name: 'Test Product', category: 'Test', default_price: 100, quantity: 50) }

    it 'initializes attributes and returns values' do
      order_item = OrderItem.new(order: order, product: product, quantity: 3, price: 150.0)
      expect(order_item.quantity).to eq(3)
      expect(order_item.price).to eq(150.0)
      expect(order_item.order).to eq(order)
      expect(order_item.product).to eq(product)
    end

    it 'allows updating attributes' do
      order_item = OrderItem.new(order: order, product: product)
      order_item.quantity = 5
      order_item.price = 200.0
      expect(order_item.quantity).to eq(5)
      expect(order_item.price).to eq(200.0)
    end

    it 'stores price as Float type' do
      order_item = OrderItem.create!(order: order, product: product, quantity: 2, price: 99.99)
      expect(order_item.price).to be_a(Float)
      expect(order_item.price).to eq(99.99)
    end

    it 'stores quantity as Integer type' do
      order_item = OrderItem.create!(order: order, product: product, quantity: 7, price: 100.0)
      expect(order_item.quantity).to be_a(Integer)
      expect(order_item.quantity).to eq(7)
    end

    it 'stores timestamps' do
      order_item = OrderItem.create!(order: order, product: product, quantity: 2, price: 100.0)
      expect(order_item.created_at).to be_present
      expect(order_item.updated_at).to be_present
    end
  end

  describe 'price field behavior' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }
    let(:order) { user.orders.create!(status: 'pending') }
    let(:product) { Product.create!(name: 'Test Product', category: 'Test', default_price: 100, quantity: 50) }

    it 'stores price at order time independently from product default_price' do
      order_item = OrderItem.create!(order: order, product: product, quantity: 2, price: 85.0)

      # Change product price after order item creation
      product.update!(default_price: 120)

      # Order item price should remain unchanged
      order_item.reload
      expect(order_item.price).to eq(85.0)
      expect(product.default_price).to eq(120)
    end

    it 'allows different prices for same product in different order items' do
      order_item1 = OrderItem.create!(order: order, product: product, quantity: 1, price: 100.0)

      # Create another order with different price for same product
      order2 = user.orders.create!(status: 'pending')
      order_item2 = OrderItem.create!(order: order2, product: product, quantity: 1, price: 110.0)

      expect(order_item1.price).to eq(100.0)
      expect(order_item2.price).to eq(110.0)
    end
  end
end
