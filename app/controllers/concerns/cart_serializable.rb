module CartSerializable
  extend ActiveSupport::Concern

  private

  def cart_json(cart)
    {
      id: cart.id.to_s,
      items: cart.cart_items.select { |item| item.product }.map do |item|
        {
          id: item.id.to_s,
          product: {
            id: item.product.id.to_s,
            name: item.product.name,
            price: item.product.default_price
          },
          quantity: item.quantity,
          subtotal: item.subtotal
        }
      end
    }
  end
end
