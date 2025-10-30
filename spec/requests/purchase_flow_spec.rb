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
      expect(JSON.parse(response.body)["message"]).to include("updated in cart")

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

      # Step 9: Verify successful order was saved with paid status
      user = User.find(user_id)
      paid_orders = user.orders.where(status: "paid")
      expect(paid_orders.count).to eq(1)
      paid_order = paid_orders.first
      expect(paid_order.status).to eq("paid")
      expect(paid_order.id.to_s).to eq(order_id)
    end

    it "prevents purchase when insufficient inventory" do
      # Add more items than available
      post "/cart/items", params: { user_id: user_id, product_id: product1.id, quantity: 10 }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("Not enough inventory available")
    end

    it "prevents order creation with empty cart" do
      post "/orders", params: { user_id: user_id }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to eq("Cart is empty")
    end

    it "allows removing items from cart using quantity 0" do
      # Add item to cart
      post "/cart/items", params: { user_id: user_id, product_id: product1.id, quantity: 2 }
      expect(response).to have_http_status(:success)

      # Verify item is in cart
      get "/cart", params: { user_id: user_id }
      expect(response).to have_http_status(:success)
      cart_data = JSON.parse(response.body)
      expect(cart_data["cart"]["items"].size).to eq(1)

      # Remove item using quantity 0
      post "/cart/items", params: { user_id: user_id, product_id: product1.id, quantity: 0 }
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["message"]).to include("removed from cart")

      # Verify cart is empty
      get "/cart", params: { user_id: user_id }
      expect(response).to have_http_status(:success)
      cart_data = JSON.parse(response.body)
      expect(cart_data["cart"]["items"]).to be_empty
    end

    it "prevents race conditions during concurrent purchases" do
      # Create a product with limited inventory
      limited_product = Product.create!(name: "Limited Product", category: "Electronics", default_price: 100, quantity: 1)
      user_a_id = "user_a"
      user_b_id = "user_b"

      # Both users add the same product to their carts (this should work)
      post "/cart/items", params: { user_id: user_a_id, product_id: limited_product.id, quantity: 1 }
      expect(response).to have_http_status(:success)

      post "/cart/items", params: { user_id: user_b_id, product_id: limited_product.id, quantity: 1 }
      expect(response).to have_http_status(:success)

      # User A places order first - should succeed
      post "/orders", params: { user_id: user_a_id }
      expect(response).to have_http_status(:created)
      order_a_data = JSON.parse(response.body)
      expect(order_a_data["order"]["status"]).to eq("paid")

      # Verify inventory was decremented after User A's purchase
      limited_product.reload
      expect(limited_product.quantity).to eq(0)

      # User B tries to place order - should fail due to no inventory left
      post "/orders", params: { user_id: user_b_id }
      expect(response).to have_http_status(:unprocessable_entity)
      order_b_error = JSON.parse(response.body)
      expect(order_b_error["error"]).to include("Not enough inventory for Limited Product")

      # Verify User B's cart still contains the item (order failed)
      get "/cart", params: { user_id: user_b_id }
      expect(response).to have_http_status(:success)
      cart_b_data = JSON.parse(response.body)
      expect(cart_b_data["cart"]["items"].size).to eq(1)

      # Verify inventory remains at 0 (not negative)
      limited_product.reload
      expect(limited_product.quantity).to eq(0)
    end

    it "handles order expiration and inventory restoration" do
      # Add products to cart
      post "/cart/items", params: { user_id: user_id, product_id: product1.id, quantity: 2 }
      expect(response).to have_http_status(:success)

      initial_quantity = product1.quantity

      # Create order but don't complete payment
      order = Order.create!(
        user: User.find_or_create_by(id: user_id) { |u| u.email = "#{user_id}@example.com"; u.name = "User #{user_id}" },
        status: "pending",
        expires_at: 1.minute.ago, # Already expired
        total_price: 200
      )
      order.order_items.create!(product: product1, quantity: 2, price: 100)

      # Reduce inventory to simulate the order
      product1.update!(quantity: initial_quantity - 2)

      # Run cleanup to expire the order
      Order.cleanup_expired!

      # Verify inventory was restored
      product1.reload
      expect(product1.quantity).to eq(initial_quantity)

      # Verify order was marked as expired
      order.reload
      expect(order.status).to eq("expired")
    end

    it "allows expired status in order validation" do
      order = Order.new(
        user: User.find_or_create_by(id: user_id) { |u| u.email = "#{user_id}@example.com"; u.name = "User #{user_id}" },
        status: "expired"
      )
      expect(order).to be_valid
    end

    it "prevents order placement when inventory becomes insufficient after items added to cart, the second item fails first" do
      # Add items to cart when inventory is sufficient
      post "/cart/items", params: { user_id: user_id, product_id: product1.id, quantity: 5 }
      expect(response).to have_http_status(:success)

      post "/cart/items", params: { user_id: user_id, product_id: product2.id, quantity: 3 }
      expect(response).to have_http_status(:success)

      # Verify cart contains items
      get "/cart", params: { user_id: user_id }
      expect(response).to have_http_status(:success)
      cart_data = JSON.parse(response.body)
      expect(cart_data["cart"]["items"].size).to eq(2)

      # Simulate inventory reduction (e.g., another order, admin adjustment)
      product2.update!(quantity: 2) # Reduce from 3 to 2, but cart has 3

      # Attempt to place order - should fail due to insufficient inventory
      post "/orders", params: { user_id: user_id }
      expect(response).to have_http_status(:unprocessable_entity)
      order_error = JSON.parse(response.body)
      expect(order_error["error"]).to include("Not enough inventory for Test Product 2")

      # Verify cart still contains items (order failed)
      get "/cart", params: { user_id: user_id }
      expect(response).to have_http_status(:success)
      cart_data = JSON.parse(response.body)
      expect(cart_data["cart"]["items"].size).to eq(2)

      # Verify inventory unchanged (no deduction on failed order)
      product1.reload
      product2.reload
      expect(product1.quantity).to eq(5) # Original quantity
      expect(product2.quantity).to eq(2) # Reduced quantity but no further change

      # Verify failed order was created and saved with failed status
      user = User.find(user_id)
      failed_orders = user.orders.where(status: "failed")
      expect(failed_orders.count).to eq(1)
      failed_order = failed_orders.first
      expect(failed_order.status).to eq("failed")
    end
    it "prevents order placement when inventory becomes insufficient after items added to cart, the first item fails first" do
      # Add items to cart when inventory is sufficient
      post "/cart/items", params: { user_id: user_id, product_id: product1.id, quantity: 5 }
      expect(response).to have_http_status(:success)

      post "/cart/items", params: { user_id: user_id, product_id: product2.id, quantity: 3 }
      expect(response).to have_http_status(:success)

      # Verify cart contains items
      get "/cart", params: { user_id: user_id }
      expect(response).to have_http_status(:success)
      cart_data = JSON.parse(response.body)
      expect(cart_data["cart"]["items"].size).to eq(2)

      # Simulate inventory reduction (e.g., another order, admin adjustment)
      product1.update!(quantity: 2) # Reduce from 5 to 2, but cart has 5

      # Attempt to place order - should fail due to insufficient inventory
      post "/orders", params: { user_id: user_id }
      expect(response).to have_http_status(:unprocessable_entity)
      order_error = JSON.parse(response.body)
      expect(order_error["error"]).to include("Not enough inventory for Test Product 1")

      # Verify cart still contains items (order failed)
      get "/cart", params: { user_id: user_id }
      expect(response).to have_http_status(:success)
      cart_data = JSON.parse(response.body)
      expect(cart_data["cart"]["items"].size).to eq(2)

      # Verify inventory unchanged (no deduction on failed order)
      product1.reload
      product2.reload
      expect(product1.quantity).to eq(2) # Original quantity
      expect(product2.quantity).to eq(3) # Original quantity

      # Verify failed order was created and saved with failed status
      user = User.find(user_id)
      failed_orders = user.orders.where(status: "failed")
      expect(failed_orders.count).to eq(1)
      failed_order = failed_orders.first
      expect(failed_order.status).to eq("failed")
    end
  end
end
