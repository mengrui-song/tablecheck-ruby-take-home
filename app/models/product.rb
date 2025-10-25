class Product
  include Mongoid::Document
  include Mongoid::Timestamps

  has_many :order_items

  field :name, type: String
  field :category, type: String
  field :default_price, type: Integer
  field :quantity, type: Integer

  validates :name, :category, presence: true
  validates :quantity, :default_price, numericality: { greater_than_or_equal_to: 0 }
  validate :quantity_not_below_pending_orders

  private

  def quantity_not_below_pending_orders
    return unless quantity_changed? && quantity.present?

    # Calculate total quantity reserved by pending orders
    pending_order_ids = Order.where(status: "pending").pluck(:id)
    pending_quantity = order_items.where(:order_id.in => pending_order_ids).sum(:quantity)


    if quantity < pending_quantity
      errors.add(:quantity, "cannot be set below #{pending_quantity} due to pending orders")
    end
  end
end
