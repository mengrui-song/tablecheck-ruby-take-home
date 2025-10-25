class User
  include Mongoid::Document
  include Mongoid::Timestamps

  field :email, type: String
  field :name, type: String

  # TODO: Add password field and authentication logic

  has_one :cart
  has_many :orders

  validates :email, presence: true, uniqueness: true
end
