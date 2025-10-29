namespace :db do
  desc "Seed data for past 2 weeks to test dynamic pricing"
  task seed_last_week: :environment do
    puts "Creating seed data for past 2 weeks..."


    # Clear existing orders and users only
    puts "Clearing existing orders and users..."
    Product.destroy_all
    Order.destroy_all
    User.destroy_all

    # import products first
    Rake::Task["products:import"].invoke
    puts "Products imported. Total products: #{Product.count}"

    # Create 100 users
    puts "Creating 100 users..."
    users = []
    100.times do |i|
      users << User.create!(
        name: "User #{i + 1}",
        email: "user#{i + 1}@example.com"
      )
    end

    # Get existing products
    products = Product.all.to_a
    puts "Using #{products.count} existing products..."

    # Create orders from past month (30 days ago to today)
    puts "Creating orders from past 2 weeks..."

    two_weeks_ago = 14.days.ago
    today = Date.current

    # Generate random orders for each day of the past 2 weeks
    (two_weeks_ago.to_date..today).each do |date|
      # Create 10-50 orders per day (more volume for better testing)
      orders_per_day = rand(10..50)

      orders_per_day.times do
        user = users.sample
        order = Order.new(user: user, status: "paid")

        # Set created_at to random time during that day
        random_time = date.beginning_of_day + rand(24.hours)
        order.created_at = random_time
        order.updated_at = random_time

        order.total_price = 0
        order.save!

        # Add 1-30 items to each order
        items_count = rand(1..30)
        items_count.times do
          product = products.sample
          quantity = rand(1..4)
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

    # Show weekly breakdown
    current_week = Date.current.beginning_of_week..Date.current.end_of_week
    previous_week = 1.week.ago.beginning_of_week..1.week.ago.end_of_week
    puts "Orders in current week: #{Order.where(created_at: current_week).count}"
    puts "Orders in previous week: #{Order.where(created_at: previous_week).count}"

    # Show some sample data
    puts "\n📊 Sample recent orders:"
    Order.where(created_at: 3.days.ago..today).limit(5).each do |order|
      puts "Order #{order.id}: #{order.user.name} - ￥#{order.total_price} - #{order.created_at.strftime('%Y-%m-%d %H:%M')}"
    end
  end
end
