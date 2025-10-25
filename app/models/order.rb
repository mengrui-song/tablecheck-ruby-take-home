class Order
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :user
  has_many :order_items, dependent: :destroy

  field :status, type: String, default: "pending" # pending, paid
  field :total_price, type: Float

  validates :status, inclusion: { in: %w[pending paid] }

  # Place order and reduce inventory
  def place!(cart)
    self.total_price = 0
    save!

    cart.cart_items.each do |cart_item|
      product = cart_item.product
      # TODO lock product for update
      product.reload
      if product.quantity < cart_item.quantity
        raise "Not enough inventory for #{product.name}"
      end

      # Create order item
      order_items.create!(
        product: product,
        quantity: cart_item.quantity,
        price: product.default_price
      )

      # Reduce inventory
      product.inc(quantity: -cart_item.quantity)

      # Add to order total
      self.total_price += cart_item.quantity * product.default_price
    end

    # Now that total is calculated, mark as paid
    self.status = "paid"
    save!

    # Clear cart
    cart.cart_items.destroy_all
  end
end
