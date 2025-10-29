namespace :db do
  desc "Seed data for last week to test dynamic pricing"
  task seed_last_week: :environment do
    puts "Creating seed data for last week..."

    # Check if products exist
    if Product.count == 0
      puts "❌ No products found. Please run 'rake products:import' first to import products from inventory.csv"
      exit 1
    end

    # Clear existing orders and users only
    puts "Clearing existing orders and users..."
    Order.destroy_all
    User.destroy_all

    # Create users
    puts "Creating users..."
    users = [
      User.create!(name: "John Doe", email: "john@example.com"),
      User.create!(name: "Jane Smith", email: "jane@example.com"),
      User.create!(name: "Bob Wilson", email: "bob@example.com"),
      User.create!(name: "Alice Brown", email: "alice@example.com"),
      User.create!(name: "Charlie Davis", email: "charlie@example.com")
    ]

    # Get existing products
    products = Product.all.to_a
    puts "Using #{products.count} existing products..."

    # Create orders from last week (7 days ago to 1 day ago)
    puts "Creating orders from last week..."

    one_week_ago = 7.days.ago
    yesterday = 1.day.ago

    # Generate random orders for each day of last week
    (one_week_ago.to_date..yesterday.to_date).each do |date|
      # Create 3-8 orders per day
      orders_per_day = rand(3..8)

      orders_per_day.times do
        user = users.sample
        order = Order.new(user: user, status: "paid")

        # Set created_at to random time during that day
        random_time = date.beginning_of_day + rand(24.hours)
        order.created_at = random_time
        order.updated_at = random_time

        order.total_price = 0
        order.save!

        # Add 1-4 items to each order
        items_count = rand(1..4)
        items_count.times do
          product = products.sample
          quantity = rand(1..3)
          price = product.current_price

          order_item = order.order_items.create!(
            product: product,
            quantity: quantity,
            price: price
          )
          order_item.created_at = random_time
          order_item.updated_at = random_time
          order_item.save!

          order.total_price += quantity * price
        end

        order.save!
        print "."
      end
    end

    puts "\n"
    puts "✅ Seed data created successfully!"
    puts "Users: #{User.count}"
    puts "Products: #{Product.count}"
    puts "Orders: #{Order.count}"
    puts "Order Items: #{OrderItem.count}"
    puts "Orders from last week: #{Order.where(created_at: one_week_ago..yesterday).count}"

    # Show some sample data
    puts "\n📊 Sample orders from last week:"
    Order.where(created_at: one_week_ago..yesterday).limit(5).each do |order|
      puts "Order #{order.id}: #{order.user.name} - ￥#{order.total_price} - #{order.created_at.strftime('%Y-%m-%d %H:%M')}"
    end
  end
end
