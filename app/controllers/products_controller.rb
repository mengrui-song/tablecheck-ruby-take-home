class ProductsController < ApplicationController
  # GET /products
  def index
    products = Product.all
    render json: products.map { |p| product_json(p) }, status: :ok
  end

  # GET /products/:id
  def show
    product = Product.find(params[:id])
    render json: product_json(product), status: :ok
  rescue Mongoid::Errors::DocumentNotFound
    render json: { error: "Product not found" }, status: :not_found
  end

  private

  def product_json(product)
    {
      id: product.id.to_s,
      name: product.name,
      category: product.category,
      price: calculate_dynamic_price(product),
      quantity: product.quantity
    }
  end

  def calculate_dynamic_price(product)
    # TODO: Implement dynamic pricing logic here
    product.default_price
  end
end
