require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      user = User.new(email: 'test@example.com', name: 'Test User')
      expect(user).to be_valid
    end

    it 'requires an email' do
      user = User.new(name: 'Test User')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it 'requires a unique email' do
      User.create!(email: 'test@example.com', name: 'First User')
      user = User.new(email: 'test@example.com', name: 'Second User')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('has already been taken')
    end
  end

  describe 'associations' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }

    it 'has one cart' do
      expect(user).to respond_to(:cart)
      cart = user.create_cart
      expect(user.cart).to eq(cart)
    end

    it 'has many orders' do
      expect(user).to respond_to(:orders)
      order = user.orders.create!
      expect(user.orders).to include(order)
    end
  end

  describe 'attributes' do
    it 'allows setting and getting email' do
      user = User.new
      user.email = 'user@example.com'
      expect(user.email).to eq('user@example.com')
    end

    it 'allows setting and getting name' do
      user = User.new
      user.name = 'John Doe'
      expect(user.name).to eq('John Doe')
    end
  end
end
