class Cart
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :user
  has_many :cart_items, dependent: :destroy

  def update_product(product_id, qty = 1)
    # Validate quantity
    if qty < 0
      raise ArgumentError, "Quantity cannot be negative"
    end
    # Validate product existence
    product = Product.where(id: product_id).first
    unless product
      raise ArgumentError, "Product with id #{product_id} does not exist"
    end

    item = cart_items.find_or_initialize_by(product_id: product_id)

    if qty == 0
      # Remove item from cart if quantity is 0
      item.destroy if item.persisted?
    else
      # Update or set the quantity
      item.quantity = qty
      item.save!
    end

    # Ensure cart_items association is reloaded to reflect changes
    reload
  end

  def total_price
    # Eager load products to avoid N+1 queries
    items_with_products = cart_items.includes(:product)

    total_price = items_with_products.sum do |item|
      if item.product
        item.quantity * item.product.current_price
      else
        0
      end
    end

    total_price
  end

  # Helper methods for clarity
  def distinct_products_count
    cart_items.count
  end

  def total_items_count
    cart_items.sum(:quantity)
  end

  def empty?
    cart_items.empty?
  end
end
