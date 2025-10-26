require 'rails_helper'

RSpec.describe Product, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      product = Product.new(name: 'MC Hammer Pants', category: 'Footwear', default_price: 3005, quantity: 285)
      expect(product).to be_valid
    end

    it 'requires a name' do
      product = Product.new(category: 'Footwear', default_price: 3005, quantity: 285)
      expect(product).not_to be_valid
      expect(product.errors[:name]).to include("can't be blank")
    end

    it 'requires a category' do
      product = Product.new(name: 'MC Hammer Pants', default_price: 3005, quantity: 285)
      expect(product).not_to be_valid
      expect(product.errors[:category]).to include("can't be blank")
    end

    it 'requires quantity to be greater than or equal to 0' do
      product = Product.new(name: 'Test Product', category: 'Test', default_price: 100, quantity: -1)
      expect(product).not_to be_valid
      expect(product.errors[:quantity]).to include('must be greater than or equal to 0')
    end

    it 'requires default_price to be greater than or equal to 0' do
      product = Product.new(name: 'Test Product', category: 'Test', default_price: -100, quantity: 10)
      expect(product).not_to be_valid
      expect(product.errors[:default_price]).to include('must be greater than or equal to 0')
    end

    it 'allows zero quantity' do
      product = Product.new(name: 'Test Product', category: 'Test', default_price: 100, quantity: 0)
      expect(product).to be_valid
    end

    it 'allows zero price' do
      product = Product.new(name: 'Free Product', category: 'Test', default_price: 0, quantity: 10)
      expect(product).to be_valid
    end

    it 'prevents quantity update below pending order requirements' do
      product = Product.create!(name: 'Test Product', category: 'Test', default_price: 100, quantity: 10)
      user = User.create!(email: 'test@example.com', name: 'Test User')
      order = user.orders.create!(status: 'pending')
      order.order_items.create!(product: product, quantity: 5, price: 100)

      product.quantity = 3
      expect(product).not_to be_valid
      expect(product.errors[:quantity]).to include('cannot be set below 5 due to pending orders')
    end

    it 'allows quantity update when sufficient for pending orders' do
      product = Product.create!(name: 'Test Product', category: 'Test', default_price: 100, quantity: 10)
      user = User.create!(email: 'test@example.com', name: 'Test User')
      order = user.orders.create!(status: 'pending')
      order.order_items.create!(product: product, quantity: 5, price: 100)

      product.quantity = 7
      expect(product).to be_valid
    end

    it 'ignores paid orders when validating quantity' do
      product = Product.create!(name: 'Test Product', category: 'Test', default_price: 100, quantity: 10)
      user = User.create!(email: 'test@example.com', name: 'Test User')
      order = user.orders.create!(status: 'paid')
      order.order_items.create!(product: product, quantity: 5, price: 100)

      product.quantity = 1
      expect(product).to be_valid
    end

    it 'handles multiple pending orders from different users' do
      product = Product.create!(name: 'Test Product', category: 'Test', default_price: 100, quantity: 20)
      user1 = User.create!(email: 'user1@example.com', name: 'User 1')
      user2 = User.create!(email: 'user2@example.com', name: 'User 2')
      
      order1 = user1.orders.create!(status: 'pending')
      order1.order_items.create!(product: product, quantity: 3, price: 100)
      
      order2 = user2.orders.create!(status: 'pending')
      order2.order_items.create!(product: product, quantity: 5, price: 100)

      product.quantity = 7
      expect(product).not_to be_valid
      expect(product.errors[:quantity]).to include('cannot be set below 8 due to pending orders')
    end

    it 'allows updating other attributes when quantity is unchanged' do
      product = Product.create!(name: 'Test Product', category: 'Test', default_price: 100, quantity: 10)
      product.name = 'Updated Product'
      product.default_price = 150
      expect(product).to be_valid
    end

    it 'validates presence of required fields' do
      product = Product.new
      expect(product).not_to be_valid
      expect(product.errors[:name]).to include("can't be blank")
      expect(product.errors[:category]).to include("can't be blank")
    end

    it 'allows maximum safe integer values' do
      product = Product.new(name: 'Test', category: 'Test', default_price: 999999999, quantity: 999999999)
      expect(product).to be_valid
    end
  end

  describe 'associations' do
    let(:product) { Product.create!(name: 'Test Product', category: 'Test', default_price: 100, quantity: 50) }

    it 'has many order_items' do
      expect(product).to respond_to(:order_items)

      # Create a user and order to test the association
      user = User.create!(email: 'test@example.com', name: 'Test User')
      order = user.orders.create!
      order_item = order.order_items.create!(product: product, quantity: 2, price: 100)

      expect(product.order_items).to include(order_item)
    end
  end

  describe 'attributes' do
    it 'initializes attributes and returns values' do
      # Use provided data: MC Hammer Pants	Footwear	3005	285
      product = Product.new(name: 'MC Hammer Pants', category: 'Footwear', default_price: 3005, quantity: 285)
      expect(product.name).to eq('MC Hammer Pants')
      expect(product.category).to eq('Footwear')
      expect(product.default_price).to eq(3005)
      expect(product.quantity).to eq(285)
    end

    it 'allows updating attributes' do
      product = Product.new
      product.name = 'Banana'
      product.default_price = 500
      expect(product.name).to eq('Banana')
      expect(product.default_price).to eq(500)
    end

    it 'allows setting and getting category' do
      product = Product.new
      product.category = 'Electronics'
      expect(product.category).to eq('Electronics')
    end

    it 'allows setting and getting quantity' do
      product = Product.new
      product.quantity = 50
      expect(product.quantity).to eq(50)
    end
  end
end
