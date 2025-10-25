class CartsController < ApplicationController
  include CartSerializable
  
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
    # TODO: Replace with actual user authentication
    user_id = params[:user_id] || "1"
    user = User.find_or_create_by(id: user_id) do |u|
      u.email = "user#{user_id}@example.com"
      u.name = "User #{user_id}"
    end
    @cart = user.cart || user.create_cart
  end
end
