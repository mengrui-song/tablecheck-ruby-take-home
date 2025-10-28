require 'rails_helper'

RSpec.describe "Products", type: :request do
  describe "GET /products" do
    let!(:product1) { Product.create!(name: "P1", category: "C1", default_price: 100, quantity: 10) }
    let!(:product2) { Product.create!(name: "P2", category: "C2", default_price: 200, quantity: 5) }

    it "returns a list of products with dynamic price" do
      get "/products"
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body).to be_an(Array)
      expect(body.size).to eq(2)

      ids = body.map { |p| p["id"] }
      expect(ids).to contain_exactly(product1.id, product2.id)

      item = body.find { |p| p["id"] == product1.id.to_s }
      expect(item["name"]).to eq(product1.name)
      expect(item["category"]).to eq(product1.category)
      expect(item["price"]).to eq(product1.current_price)
      expect(item["quantity"]).to eq(product1.quantity)
    end
  end

  describe "GET /products/:id" do
    let!(:product) { Product.create!(name: "Widget", category: "Gadgets", default_price: 50, quantity: 20) }

    it "returns the product with dynamic price" do
      get "/products/#{product.id}"
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["id"]).to eq(product.id.to_s)
      expect(body["name"]).to eq(product.name)
      expect(body["category"]).to eq(product.category)
      expect(body["price"]).to eq(product.current_price)
      expect(body["quantity"]).to eq(product.quantity)
    end

    it "returns 404 when product not found" do
      get "/products/0"
      expect(response).to have_http_status(:not_found)

      body = JSON.parse(response.body)
      expect(body["error"]).to eq("Product not found")
    end
  end
end
