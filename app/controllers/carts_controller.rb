class CartsController < ApplicationController
  include CartSerializable
  include CartManagement

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
end
