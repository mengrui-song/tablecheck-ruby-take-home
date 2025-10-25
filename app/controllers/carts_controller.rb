class CartsController < ApplicationController
  before_action :set_cart

  # GET /cart
  def show
    render json: {
      cart: cart_json(@cart),
      total_price: @cart.total_price
    }
  end

  # DELETE /cart
  def destroy
    @cart.cart_items.destroy_all
    render json: { message: "Cart cleared" }
  end

  private

  def set_cart
    user_id = params[:user_id] || "1"
    user = User.find_or_create_by(id: user_id) do |u|
      u.email = "user#{user_id}@example.com"
      u.name = "User #{user_id}"
    end
    @cart = user.cart || user.create_cart
  end

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
