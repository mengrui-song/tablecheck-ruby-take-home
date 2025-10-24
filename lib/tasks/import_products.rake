require "csv"

namespace :products do
  desc "Import products from data/inventory.csv"
  task import: :environment do
    file_path = Rails.root.join("data", "inventory.csv")
    raise "File not found: #{file_path}" unless File.exist?(file_path)

    puts "Importing products from #{file_path}..."
    CSV.foreach(file_path, headers: true) do |row|
      attrs = row.to_h.symbolize_keys

      # Skip rows with missing required fields
      if attrs[:NAME].blank? || attrs[:CATEGORY].blank?
        puts "Skipping row with missing name or category: #{attrs}"
        next
      end

      # Use name + category as unique key to prevent duplicates
      product = Product.find_or_initialize_by(name: attrs[:NAME], category: attrs[:CATEGORY])

      if product.new_record?
        product.quantity = attrs[:QTY].to_i
        product.price = attrs[:PRICE].to_f

        begin
          product.save!
          puts "Created product: #{product.name}"
        rescue Mongoid::Errors::Validations => e
          puts "Skipping invalid product: #{attrs[:NAME]} (#{e.message})"
        end
      else
        puts "Product already exists, skipping: #{product.name}"
      end
    end

    puts "✅ Import complete. Total products: #{Product.count}"
  end
end
