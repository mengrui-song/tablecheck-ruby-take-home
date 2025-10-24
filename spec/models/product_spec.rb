require 'rails_helper'

RSpec.describe Product, type: :model do
  it 'initializes attributes and returns values' do
    # Use provided data: MC Hammer Pants	Footwear	3005	285
    product = Product.new(name: 'MC Hammer Pants', category: 'Footwear', price: 3005, quantity: 285)
    expect(product.name).to eq('MC Hammer Pants')
    expect(product.category).to eq('Footwear')
    expect(product.price).to eq(3005)
    expect(product.quantity).to eq(285)
  end

  it 'allows updating attributes' do
    product = Product.new
    product.name = 'Banana'
    product.price = 0.5
    expect(product.name).to eq('Banana')
    expect(product.price).to eq(0.5)
  end
end
