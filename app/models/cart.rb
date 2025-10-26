class Cart
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :user
  has_many :cart_items, dependent: :destroy

  def add_product(product_id, qty = 1)
    item = cart_items.find_or_initialize_by(product_id: product_id)
    if item.persisted?
      item.quantity += qty
    else
      item.quantity = qty
    end
    item.save
    # Ensure cart_items association is reloaded to reflect changes
    reload
  end

  def total_price
    # Eager load products to avoid N+1 queries
    items_with_products = cart_items.includes(:product)

    total_price = items_with_products.sum do |item|
      if item.product
        item.quantity * item.product.default_price # TODO update the price to be dynamic price
      else
        0
      end
    end

    total_price
  end
end
