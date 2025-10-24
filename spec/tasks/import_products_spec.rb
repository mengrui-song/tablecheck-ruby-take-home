# lib/tasks/import_products_test.rake
require "rails_helper"
require "rake"
require "fileutils"
require "stringio"

RSpec.describe "products:import rake task" do
  let(:data_dir) { Rails.root.join("data") }
  let(:csv_path) { data_dir.join("inventory.csv") }

  before(:all) do
    # Load the rake task from lib/tasks/import_products.rake
    Rake.application.rake_require("tasks/import_products", [ Rails.root.join("lib").to_s ])
    # Ensure environment task exists for the rake task to depend on
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
  end

  before(:each) do
    Product.delete_all
    FileUtils.mkdir_p(data_dir)
  end

  after(:each) do
    FileUtils.rm_f(csv_path)
  end

  def write_csv(content)
    File.open(csv_path, "w") { |f| f.write(content) }
  end

  def run_task_capture_stdout
    out = StringIO.new
    original_stdout = $stdout
    begin
      $stdout = out
      Rake::Task["products:import"].reenable
      Rake::Task["products:import"].invoke
    ensure
      $stdout = original_stdout
    end
    out.string
  end

  it "imports valid products from CSV and skips invalid or duplicate rows" do
    csv = <<~CSV
      NAME,CATEGORY,QTY,PRICE
      Widget A,Gadgets,10,19.99
      Widget B,Gadgets,5,9.5
      ,Gadgets,1,1.0
      Widget A,Gadgets,2,19.99
    CSV

    write_csv(csv)

    output = run_task_capture_stdout

    expect(Product.count).to eq(2)

    widget_a = Product.where(name: "Widget A", category: "Gadgets").first
    widget_b = Product.where(name: "Widget B", category: "Gadgets").first

    expect(widget_a).not_to be_nil
    expect(widget_a.quantity.to_i).to eq(10)
    expect(widget_a.price.to_f).to be_within(0.001).of(19.99)

    expect(widget_b).not_to be_nil
    expect(widget_b.quantity.to_i).to eq(5)
    expect(widget_b.price.to_f).to be_within(0.001).of(9.5)

    # Optional assertions on output messages
    expect(output).to include("Importing products")
    expect(output).to include("Created product: Widget A")
    expect(output).to include("Created product: Widget B")
    expect(output).to include("Skipping row with missing name or category")
    expect(output).to include("Product already exists, skipping")
  end

  it "does not create duplicates when task is run multiple times" do
    csv = <<~CSV
      NAME,CATEGORY,QTY,PRICE
      Solo,Gear,3,3.33
    CSV

    write_csv(csv)

    first_output = run_task_capture_stdout
    expect(Product.count).to eq(1)

    second_output = run_task_capture_stdout
    expect(Product.count).to eq(1)

    expect(first_output).to include("Created product: Solo")
    expect(second_output).to include("Product already exists, skipping")
  end
end
