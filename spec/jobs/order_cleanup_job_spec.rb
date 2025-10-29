require 'rails_helper'

RSpec.describe OrderCleanupJob, type: :job do
  let!(:user) { User.create!(email: "test@example.com", name: "Test User") }
  let!(:product) { Product.create!(name: "Test Product", category: "Electronics", default_price: 100, quantity: 10) }

  describe '#perform' do
    context 'when there are expired orders' do
      let!(:expired_order) do
        order = Order.create!(
          user: user,
          status: "pending",
          expires_at: 1.hour.ago,
          total_price: 200
        )
        # Create order items that reduced inventory
        order.order_items.create!(
          product: product,
          quantity: 5,
          price: 100
        )
        order
      end

      let!(:active_order) do
        order = Order.create!(
          user: user,
          status: "pending",
          expires_at: 1.hour.from_now,
          total_price: 100
        )
        order.order_items.create!(
          product: product,
          quantity: 2,
          price: 100
        )
        order
      end

      let!(:paid_order) do
        order = Order.create!(
          user: user,
          status: "paid",
          expires_at: nil,
          total_price: 300
        )
        order.order_items.create!(
          product: product,
          quantity: 3,
          price: 100
        )
        order
      end

      before do
        # Start with higher inventory since we can't reduce below pending orders (7 total pending)
        product.update!(quantity: 15) # Enough for all pending orders + some buffer
      end

      it 'cleans up expired orders and restores inventory' do
        expect {
          OrderCleanupJob.new.perform
        }.to change { expired_order.reload.status }.from("pending").to("expired")

        # Verify inventory is restored only for expired order
        expect(product.reload.quantity).to eq(20) # 15 + 5 (from expired order)

        # Verify other orders are not affected
        expect(active_order.reload.status).to eq("pending")
        expect(paid_order.reload.status).to eq("paid")
      end

      it 'logs the cleanup action' do
        expect(Rails.logger).to receive(:info)
          .with(/Cleaned up expired orders at/)

        OrderCleanupJob.new.perform
      end

      it 'calls Order.cleanup_expired!' do
        expect(Order).to receive(:cleanup_expired!)

        OrderCleanupJob.new.perform
      end
    end

    context 'when there are no expired orders' do
      let!(:active_order) do
        Order.create!(
          user: user,
          status: "pending",
          expires_at: 1.hour.from_now,
          total_price: 100
        )
      end

      it 'completes without errors' do
        expect { OrderCleanupJob.new.perform }.not_to raise_error
      end

      it 'still logs the cleanup action' do
        expect(Rails.logger).to receive(:info)
          .with(/Cleaned up expired orders at/)

        OrderCleanupJob.new.perform
      end
    end

    context 'when there are failed orders' do
      let!(:failed_order) do
        order = Order.create!(
          user: user,
          status: "failed",
          expires_at: 1.hour.ago, # Even though expired, should not be processed
          total_price: 100
        )
        order.order_items.create!(
          product: product,
          quantity: 2,
          price: 100
        )
        order
      end

      it 'does not process failed orders' do
        initial_quantity = product.quantity

        OrderCleanupJob.new.perform

        # Failed order should remain unchanged
        expect(failed_order.reload.status).to eq("failed")

        # Inventory should not be affected
        expect(product.reload.quantity).to eq(initial_quantity)
      end
    end

    context 'with multiple expired orders' do
      let!(:product2) { Product.create!(name: "Test Product 2", category: "Clothing", default_price: 50, quantity: 20) }

      let!(:expired_order1) do
        order = Order.create!(
          user: user,
          status: "pending",
          expires_at: 2.hours.ago,
          total_price: 300
        )
        order.order_items.create!(product: product, quantity: 3, price: 100)
        order
      end

      let!(:expired_order2) do
        order = Order.create!(
          user: user,
          status: "pending",
          expires_at: 30.minutes.ago,
          total_price: 100
        )
        order.order_items.create!(product: product2, quantity: 2, price: 50)
        order
      end

      before do
        # Keep enough inventory to satisfy pending orders (no reduction needed)
        # product starts with 10, product2 starts with 20
      end

      it 'cleans up all expired orders and restores all inventory' do
        OrderCleanupJob.new.perform

        # Both orders should be expired
        expect(expired_order1.reload.status).to eq("expired")
        expect(expired_order2.reload.status).to eq("expired")

        # Inventory should be restored for both products
        expect(product.reload.quantity).to eq(13)   # 10 + 3 = 13
        expect(product2.reload.quantity).to eq(22)  # 20 + 2 = 22
      end
    end

    context 'when Order.cleanup_expired! raises an error' do
      before do
        allow(Order).to receive(:cleanup_expired!).and_raise(StandardError, "Test error")
      end

      it 'allows the error to propagate' do
        expect { OrderCleanupJob.new.perform }.to raise_error(StandardError, "Test error")
      end
    end
  end

  describe 'job configuration' do
    it 'uses the default queue' do
      expect(OrderCleanupJob.queue_name).to eq('default')
    end

    it 'can be enqueued' do
      expect { OrderCleanupJob.perform_later }.to have_enqueued_job(OrderCleanupJob)
    end
  end
end
