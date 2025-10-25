class OrdersController < ApplicationController
  before_action :set_user

  # GET /orders
  def index
    orders = @user.orders.desc(:created_at)
    render json: {
      orders: orders.map { |order| order_json(order) }
    }
  end

  # GET /orders/:id
  def show
    order = @user.orders.find(params[:id])
    render json: { order: order_json(order) }
  rescue Mongoid::Errors::DocumentNotFound
    render json: { error: "Order not found" }, status: :not_found
  end

  # POST /orders
  def create
    cart = @user.cart

    if !cart || cart.cart_items.empty?
      render json: { error: "Cart is empty" }, status: :unprocessable_entity
      return
    end

    # Check inventory for all items before creating order
    cart.cart_items.each do |cart_item|
      product = cart_item.product
      if !product
        render json: { error: "Product not found for cart item" }, status: :unprocessable_entity
        return
      end

      if product.quantity < cart_item.quantity
        render json: {
          error: "Not enough inventory for #{product.name}. Available: #{product.quantity}, Requested: #{cart_item.quantity}"
        }, status: :unprocessable_entity
        return
      end
    end

    # Create and place the order
    order = @user.orders.build

    begin
      order.place!(cart)
      render json: {
        message: "Order placed successfully",
        order: order_json(order)
      }, status: :created
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  private

  def set_user
    # For now, using a simple approach - get user from params
    # In a real app, this would come from authentication
    user_id = params[:user_id] || "1"
    @user = User.find_or_create_by(id: user_id) do |u|
      u.email = "user#{user_id}@example.com"
      u.name = "User #{user_id}"
    end
  end

  def order_json(order)
    {
      id: order.id.to_s,
      status: order.status,
      total_price: order.total_price,
      created_at: order.created_at,
      items: order.order_items.map do |item|
        {
          id: item.id.to_s,
          product: {
            id: item.product.id.to_s,
            name: item.product.name
          },
          quantity: item.quantity,
          price: item.price,
          subtotal: item.quantity * item.price
        }
      end
    }
  end
end
