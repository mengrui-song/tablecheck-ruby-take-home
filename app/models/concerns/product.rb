class Product
  include Mongoid::Document
  field :name, type: String
  field :category, type: String
  field :price, type: Float
  field :quantity, type: Integer
end
