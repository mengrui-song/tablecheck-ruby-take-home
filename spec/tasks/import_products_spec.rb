require "rails_helper"
require "rake"

RSpec.describe "products:import", type: :task do
  before(:all) do
    Rake.application.rake_require("tasks/import_products", [ Rails.root.join("lib").to_s ])
    Rake::Task.define_task(:environment)
  end

  it "imports 50 products from data/inventory.csv" do
    expect(Product.count).to eq(0)

    Rake::Task["products:import"].reenable
    Rake::Task["products:import"].invoke

    expect(Product.count).to eq(50)
  end
end
