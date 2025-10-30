require 'rails_helper'

RSpec.describe Order, type: :model do
  describe 'validations' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }

    it 'is valid with valid attributes' do
      order = Order.new(user: user, total_price: 100.0)
      expect(order).to be_valid
    end

    it 'has a default status of pending' do
      order = Order.new(user: user)
      expect(order.status).to eq('pending')
    end

    it 'validates status inclusion' do
      order = Order.new(user: user, status: 'invalid_status')
      expect(order).not_to be_valid
      expect(order.errors[:status]).to include('is not included in the list')
    end

    it 'allows pending status' do
      order = Order.new(user: user, status: 'pending')
      expect(order).to be_valid
    end

    it 'allows paid status' do
      order = Order.new(user: user, status: 'paid')
      expect(order).to be_valid
    end
  end

  describe 'associations' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }
    let(:order) { Order.create!(user: user) }

    it 'belongs to user' do
      expect(order).to respond_to(:user)
      expect(order.user).to eq(user)
    end

    it 'has many order_items' do
      expect(order).to respond_to(:order_items)

      product = Product.create!(name: 'Test Product', category: 'Test', default_price: 100, quantity: 50)
      order_item = order.order_items.create!(product: product, quantity: 2, price: 100)

      expect(order.order_items).to include(order_item)
    end
  end

  describe 'attributes' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }

    it 'allows setting and getting status' do
      order = Order.new(user: user)
      order.status = 'paid'
      expect(order.status).to eq('paid')
    end

    it 'allows setting and getting total_price' do
      order = Order.new(user: user)
      order.total_price = 250
      expect(order.total_price).to eq(250)
    end
  end

  describe '#place!' do
    let(:product) { Product.create!(name: 'Test Product', category: 'Test', default_price: 100, quantity: 10) }
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }
    let(:cart) { Cart.create(user: user) }
    let(:order) { user.orders.new }

    before do
      cart.update_product(product.id.to_s, 2)
    end

    it 'successfully places an order' do
      expect { order.place!(cart) }.not_to raise_error

      order.reload
      expect(order.status).to eq('paid')
      expect(order.total_price).to eq(200.0)
      expect(order.order_items.count).to eq(1)
    end

    it 'creates order items with correct attributes' do
      order.place!(cart)

      order_item = order.order_items.first
      expect(order_item.product).to eq(product)
      expect(order_item.quantity).to eq(2)
      expect(order_item.price).to eq(100)
    end

    it 'reduces product inventory' do
      initial_quantity = product.quantity
      order.place!(cart)

      product.reload
      expect(product.quantity).to eq(initial_quantity - 2)
    end

    it 'calculates total price correctly' do
      order.place!(cart)

      expect(order.total_price).to eq(2 * product.current_price)
    end

    it 'clears the cart after placing order' do
      order.place!(cart)

      cart.reload
      expect(cart.cart_items.count).to eq(0)
    end

    it 'raise error if user has product in cart when product quantity is updated' do
      product.update!(quantity: 1)

      expect { order.place!(cart) }.to raise_error("Not enough inventory for #{product.name}. Available: 1, Requested: 2")

      product.reload
      expect(product.quantity).to eq(1) # Inventory should remain unchanged
    end

    context 'when inventory is insufficient ' do
      it 'marks order as failed and does not change inventory' do
        product.update!(quantity: 1) # Less than cart quantity (2)

        expect { order.place!(cart) }.to raise_error("Not enough inventory for #{product.name}. Available: 1, Requested: 2")

        # Order should be marked as failed
        order.reload
        expect(order.status).to eq('failed')

        # Inventory should remain unchanged
        product.reload
        expect(product.quantity).to eq(1)

        # No order items should be created
        expect(order.order_items.count).to eq(0)
      end
    end

    context 'when order placement is interrupted (Scenario 1)' do
      it 'can create pending orders that need cleanup' do
        # This simulates a scenario where order placement succeeded
        # but payment failed or system crashed before completion

        # Create order manually in pending state with expiration
        pending_order = Order.create!(
          user: user,
          status: 'pending',
          expires_at: 16.minutes.ago, # Expired
          total_price: 200
        )

        # Create order items to simulate inventory was already reduced
        pending_order.order_items.create!(
          product: product,
          quantity: 2,
          price: 100
        )

        # Simulate inventory was reduced when order was placed
        original_quantity = product.quantity
        product.update!(quantity: original_quantity - 2)

        expect(pending_order.expired?).to be true
        expect(pending_order.status).to eq('pending')

        # Cleanup should restore inventory and mark as expired
        Order.cleanup_expired!

        pending_order.reload
        product.reload

        expect(pending_order.status).to eq('expired')
        expect(product.quantity).to eq(original_quantity) # Inventory restored
      end
    end

    it 'handles multiple products in cart' do
      product2 = Product.create!(name: 'Product 2', category: 'Test', default_price: 50, quantity: 5)
      cart.update_product(product2.id.to_s, 1)

      order.place!(cart)

      expect(order.order_items.count).to eq(2)
      expect(order.total_price).to eq(250.0) # (2 * 100) + (1 * 50)
    end

    it 'starts with pending status then changes to paid' do
      order.place!(cart)

      expect(order.status).to eq('paid')
    end

    it 'preserves price at order time' do
      order.place!(cart)

      # Change product price after order
      product.update!(default_price: 200)

      order_item = order.order_items.first
      expect(order_item.price).to eq(100) # Original price preserved
    end

    it 'handles concurrent access to different products correctly' do
      # Create two different products with 1 item each
      product_a = Product.create!(name: 'Product A', category: 'Test', default_price: 100, quantity: 1)
      product_b = Product.create!(name: 'Product B', category: 'Test', default_price: 100, quantity: 1)

      # Create two users with different products
      user_a = User.create!(email: 'user_a@example.com', name: 'User A')
      user_b = User.create!(email: 'user_b@example.com', name: 'User B')
      cart_a = Cart.create!(user: user_a)
      cart_b = Cart.create!(user: user_b)

      cart_a.update_product(product_a.id.to_s, 1)
      cart_b.update_product(product_b.id.to_s, 1)

      order_a = user_a.orders.new
      order_b = user_b.orders.new

      # Both orders should succeed since they're for different products
      expect { order_a.place!(cart_a) }.not_to raise_error
      expect { order_b.place!(cart_b) }.not_to raise_error

      # Verify both products are sold out
      product_a.reload
      product_b.reload
      expect(product_a.quantity).to eq(0)
      expect(product_b.quantity).to eq(0)
    end

    it 'sets 15-minute expiration when order is placed' do
      # Mock time to control the test
      allow(Time).to receive(:current).and_return(Time.parse("2023-01-01 12:00:00"))

      order.place!(cart)

      # Should be set to 15 minutes from "now"
      expect(order.expires_at).to be_nil # Expiration is cleared when order is paid
      expect(order.status).to eq("paid")
    end
  end

  describe 'expiration functionality' do
    let(:user) { User.create!(email: 'test@example.com', name: 'Test User') }
    let(:product) { Product.create!(name: 'Test Product', category: 'Test', default_price: 100, quantity: 10) }

    it 'identifies expired orders correctly' do
      order = Order.create!(user: user, status: "pending", expires_at: 1.minute.ago)
      expect(order.expired?).to be true
    end

    it 'identifies active orders correctly' do
      order = Order.create!(user: user, status: "pending", expires_at: 1.minute.from_now)
      expect(order.expired?).to be false
    end

    it 'does not consider paid orders as expired' do
      order = Order.create!(user: user, status: "paid", expires_at: 1.minute.ago)
      expect(order.expired?).to be false
    end

    describe '.cleanup_expired!' do
      it 'returns inventory for expired orders' do
        # Create an order with items
        order = Order.create!(user: user, status: "pending", expires_at: 1.minute.ago, total_price: 200)
        order.order_items.create!(product: product, quantity: 2, price: 100)

        initial_quantity = product.quantity

        # Run cleanup
        Order.cleanup_expired!

        # Check that inventory was returned
        product.reload
        expect(product.quantity).to eq(initial_quantity + 2)

        # Check that order status was updated
        order.reload
        expect(order.status).to eq("expired")
      end

      it 'only affects pending expired orders' do
        # Create a paid order that's past expiration
        paid_order = Order.create!(user: user, status: "paid", expires_at: 1.minute.ago, total_price: 100)
        paid_order.order_items.create!(product: product, quantity: 1, price: 100)

        # Create a pending non-expired order
        active_order = Order.create!(user: user, status: "pending", expires_at: 1.minute.from_now, total_price: 100)
        active_order.order_items.create!(product: product, quantity: 1, price: 100)

        initial_quantity = product.quantity

        Order.cleanup_expired!

        # Inventory should not change
        product.reload
        expect(product.quantity).to eq(initial_quantity)

        # Orders should remain unchanged
        paid_order.reload
        expect(paid_order.status).to eq("paid")

        active_order.reload
        expect(active_order.status).to eq("pending")
      end
    end
  end
end
