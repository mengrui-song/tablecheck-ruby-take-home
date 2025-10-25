require 'rails_helper'

RSpec.describe "Purchase Flow", type: :request do
  let!(:product1) { Product.create!(name: "Test Product 1", category: "Electronics", default_price: 10, quantity: 5) }
  let!(:product2) { Product.create!(name: "Test Product 2", category: "Books", default_price: 25, quantity: 3) }
  let(:user_id) { "test_user_1" }

  describe "Complete purchase flow" do
    it "allows user to add products to cart and complete purchase" do
      # Step 1: Check empty cart
      get "/cart", params: { user_id: user_id }
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["cart"]["items"]).to be_empty

      # Step 2: Add products to cart
      post "/cart/items", params: { user_id: user_id, product_id: product1.id, quantity: 2 }
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["message"]).to eq("Product added to cart")

      post "/cart/items", params: { user_id: user_id, product_id: product2.id, quantity: 1 }
      expect(response).to have_http_status(:success)

      # Step 3: View cart with items
      get "/cart", params: { user_id: user_id }
      expect(response).to have_http_status(:success)
      cart_data = JSON.parse(response.body)
      expect(cart_data["cart"]["items"].size).to eq(2)
      expect(cart_data["total_price"]).to eq(45) # (10 * 2) + (25 * 1)

      # Step 4: Update item quantity
      cart_item_id = cart_data["cart"]["items"].first["id"]
      patch "/cart/items/#{cart_item_id}", params: { user_id: user_id, quantity: 3 }
      expect(response).to have_http_status(:success)

      # Step 5: Create order (purchase)
      post "/orders", params: { user_id: user_id }
      expect(response).to have_http_status(:created)
      order_data = JSON.parse(response.body)
      expect(order_data["message"]).to eq("Order placed successfully")
      expect(order_data["order"]["status"]).to eq("paid")
      expect(order_data["order"]["total_price"]).to eq(55) # (10 * 3) + (25 * 1)

      # Step 6: Verify cart is cleared
      get "/cart", params: { user_id: user_id }
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["cart"]["items"]).to be_empty

      # Step 7: Verify inventory is reduced
      product1.reload
      product2.reload
      expect(product1.quantity).to eq(2) # 5 - 3 = 2
      expect(product2.quantity).to eq(2) # 3 - 1 = 2

      # Step 8: View order
      order_id = order_data["order"]["id"]
      get "/orders/#{order_id}", params: { user_id: user_id }
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["order"]["id"]).to eq(order_id)
    end

    it "prevents purchase when insufficient inventory" do
      # Add more items than available
      post "/cart/items", params: { user_id: user_id, product_id: product1.id, quantity: 10 }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to eq("Not enough inventory available")
    end

    it "prevents order creation with empty cart" do
      post "/orders", params: { user_id: user_id }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to eq("Cart is empty")
    end
  end
end
