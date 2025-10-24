class Product
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :category, type: String
  field :price, type: Float
  field :quantity, type: Integer

  validates :name, :category, presence: true
  validates :quantity, :price, numericality: { greater_than_or_equal_to: 0 }
end
