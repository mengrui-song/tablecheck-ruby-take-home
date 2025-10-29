class CartItemsController < ApplicationController
  include CartSerializable
  include CartManagement

  before_action :set_cart

  # POST /cart/items
  def create
    product = Product.find(params[:product_id])
    quantity = params[:quantity]&.to_i || 0

    # TODO: The inventory check and cart update are not atomic.
    if quantity > 0 && product.quantity < quantity
      render json: {
        error: "Not enough inventory available for #{product.name}",
        cart: cart_json(@cart),
        total_price: @cart.total_price
      }, status: :unprocessable_entity
      return
    end

    @cart.update_product(product.id, quantity)

    message = if quantity == 0
                "#{product.name} removed from cart"
    else
                "#{product.name} updated in cart"
    end

    render json: {
      message: message,
      cart: cart_json(@cart),
      total_price: @cart.total_price
    }
  rescue Mongoid::Errors::DocumentNotFound
    render json: { error: "Product not found" }, status: :not_found
  end

  # PATCH /cart/items/:id
  def update
    cart_item = @cart.cart_items.find(params[:id])
    new_quantity = params[:quantity].to_i

    if new_quantity <= 0
      cart_item.destroy
      message = "#{cart_item.product.name} removed from cart"
    else
      if cart_item.product.quantity < new_quantity
        render json: {
          error: "Not enough inventory available",
          cart: cart_json(@cart),
          total_price: @cart.total_price
        }, status: :unprocessable_entity
        return
      end

      cart_item.update!(quantity: new_quantity)
      message = "Cart item updated"
    end

    render json: {
      message: message,
      cart: cart_json(@cart),
      total_price: @cart.total_price
    }
  rescue Mongoid::Errors::DocumentNotFound
    render json: { error: "Cart item not found" }, status: :not_found
  end

  # DELETE /cart/items/:id
  def destroy
    cart_item = @cart.cart_items.find(params[:id])
    cart_item.destroy

    render json: {
      message: "Item removed from cart",
      cart: cart_json(@cart),
      total_price: @cart.total_price
    }
  rescue Mongoid::Errors::DocumentNotFound
    render json: { error: "Cart item not found" }, status: :not_found
  end
end
