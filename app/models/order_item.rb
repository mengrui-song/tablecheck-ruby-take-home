class OrderItem
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :order
  belongs_to :product

  field :quantity, type: Integer
  field :price, type: Float # price per item at order time

  validates :quantity, numericality: { greater_than: 0 }
end
