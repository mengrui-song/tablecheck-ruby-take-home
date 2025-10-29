class Order
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :user
  has_many :order_items, dependent: :destroy

  field :status, type: String, default: "pending" # pending, paid, expired
  field :total_price, type: Integer, default: 0
  field :expires_at, type: Time

  validates :status, inclusion: { in: %w[pending paid expired] }

  scope :expired, -> { where(status: "pending", :expires_at.lt => Time.current) }
  scope :active, -> { where(status: "pending", :expires_at.gt => Time.current) }

  def expired?
    status == "pending" && expires_at && expires_at < Time.current
  end

  # Place order and reduce inventory
  def place!(cart)
    # Check if cart is empty
    if cart.cart_items.empty?
      raise "Cart is empty"
    end

    # Set expiration for this order (15 minutes to complete payment)
    self.expires_at = 15.minutes.from_now
    self.total_price = 0
    save!

    cart.cart_items.each do |cart_item|
      product = cart_item.product

      # Use atomic operation to check and decrement inventory
      updated_product = Product.where(
        id: product.id,
        :quantity.gte => cart_item.quantity
      ).find_one_and_update(
        { "$inc" => { quantity: -cart_item.quantity } },
        { return_document: :after }
      )

      unless updated_product
        raise "Not enough inventory for #{product.name}"
      end

      # Create order item
      order_items.create!(
        product: product,
        quantity: cart_item.quantity,
        price: product.current_price
      )

      # Add to order total
      self.total_price += cart_item.quantity * product.current_price
    end

    # Now that total is calculated, mark as paid and clear expiration
    self.status = "paid"
    self.expires_at = nil
    save!

    # Clear cart
    cart.cart_items.destroy_all
  end

  def self.cleanup_expired!
    expired.each do |order|
      # Return inventory for expired orders
      order.order_items.each do |item|
        Product.where(id: item.product_id).inc(quantity: item.quantity)
      end
      order.update!(status: "expired")
    end
  end
end
