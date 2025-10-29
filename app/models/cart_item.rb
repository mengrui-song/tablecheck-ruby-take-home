class CartItem
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :cart
  belongs_to :product

  field :quantity, type: Integer, default: 1

  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def subtotal
    quantity * product.default_price
  end
end
