require 'rails_helper'

RSpec.describe CartItem, type: :model do
  describe 'validations' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }
    let(:cart) { Cart.create!(user: user) }
    let(:product) { Product.create!(name: 'Test Product', category: 'Test', default_price: 100, quantity: 50) }

    it 'is valid with valid attributes' do
      cart_item = CartItem.new(cart: cart, product: product, quantity: 2)
      expect(cart_item).to be_valid
    end

    it 'requires quantity to be greater than 0' do
      cart_item = CartItem.new(cart: cart, product: product, quantity: 0)
      expect(cart_item).not_to be_valid
      expect(cart_item.errors[:quantity]).to include('must be greater than 0')
    end

    it 'requires quantity to be greater than 0 for negative values' do
      cart_item = CartItem.new(cart: cart, product: product, quantity: -1)
      expect(cart_item).not_to be_valid
      expect(cart_item.errors[:quantity]).to include('must be greater than 0')
    end

    it 'defaults quantity to 1' do
      cart_item = CartItem.new(cart: cart, product: product)
      expect(cart_item.quantity).to eq(1)
    end
  end

  describe 'associations' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }
    let(:cart) { Cart.create!(user: user) }
    let(:product) { Product.create!(name: 'Test Product', category: 'Test', default_price: 100, quantity: 50) }
    let(:cart_item) { CartItem.create!(cart: cart, product: product, quantity: 2) }

    it 'belongs to cart' do
      expect(cart_item).to respond_to(:cart)
      expect(cart_item.cart).to eq(cart)
    end

    it 'belongs to product' do
      expect(cart_item).to respond_to(:product)
      expect(cart_item.product).to eq(product)
    end
  end

  describe '#subtotal' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }
    let(:cart) { Cart.create!(user: user) }
    let(:product) { Product.create!(name: 'Test Product', category: 'Test', default_price: 250, quantity: 50) }

    it 'calculates subtotal correctly' do
      cart_item = CartItem.create!(cart: cart, product: product, quantity: 3)
      expect(cart_item.subtotal).to eq(750)
    end

    it 'calculates subtotal for quantity 1' do
      cart_item = CartItem.create!(cart: cart, product: product, quantity: 1)
      expect(cart_item.subtotal).to eq(250)
    end

    it 'calculates subtotal for different product price' do
      expensive_product = Product.create!(name: 'Expensive Product', category: 'Luxury', default_price: 1000, quantity: 10)
      cart_item = CartItem.create!(cart: cart, product: expensive_product, quantity: 2)
      expect(cart_item.subtotal).to eq(2000)
    end
  end

  describe 'attributes' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }
    let(:cart) { Cart.create!(user: user) }
    let(:product) { Product.create!(name: 'Test Product', category: 'Test', default_price: 100, quantity: 50) }

    it 'allows setting and getting quantity' do
      cart_item = CartItem.new(cart: cart, product: product)
      cart_item.quantity = 5
      expect(cart_item.quantity).to eq(5)
    end

    it 'stores timestamps' do
      cart_item = CartItem.create!(cart: cart, product: product, quantity: 2)
      expect(cart_item.created_at).to be_present
      expect(cart_item.updated_at).to be_present
    end
  end
end
