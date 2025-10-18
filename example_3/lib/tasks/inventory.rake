namespace :inventory do
  desc "Expire old reservations"
  task expire_reservations: :environment do
    puts "Finding expired reservations..."

    query_service = InventoryQueryService.new
    command_handler = Inventory::Container.inventory_command_handler

    expired = query_service.find_expired_reservations

    if expired.empty?
      puts "No expired reservations found."
    else
      puts "Found #{expired.size} expired reservation(s)"

      expired.each do |reservation|
        begin
          command_handler.expire_reservation(
            product_id: reservation[:product_id],
            reservation_id: reservation[:reservation_id]
          )

          puts "  ✓ Expired reservation #{reservation[:reservation_id]} for product #{reservation[:product_id]}"
        rescue => e
          puts "  ✗ Failed to expire reservation #{reservation[:reservation_id]}: #{e.message}"
        end
      end

      # プロジェクションを更新
      puts "\nUpdating projections..."
      Projections::Container.projection_manager.call
      puts "Done!"
    end
  end

  desc "Add stock to a product"
  task :add_stock, [:product_id, :quantity] => :environment do |t, args|
    product_id = args[:product_id]
    quantity = args[:quantity].to_i

    raise "Usage: rake inventory:add_stock[product_id,quantity]" if product_id.nil? || quantity <= 0

    command_handler = Inventory::Container.inventory_command_handler

    begin
      command_handler.add_stock(
        product_id: product_id,
        quantity: quantity
      )

      puts "Added #{quantity} units to product #{product_id}"

      # プロジェクションを更新
      Projections::Container.projection_manager.call
      puts "Projections updated"
    rescue => e
      puts "Error: #{e.message}"
      exit 1
    end
  end

  desc "Show inventory for a product"
  task :show, [:product_id] => :environment do |t, args|
    product_id = args[:product_id]

    raise "Usage: rake inventory:show[product_id]" if product_id.nil?

    query_service = InventoryQueryService.new
    inventory = query_service.get_inventory(product_id)

    if inventory
      puts "\nInventory for product: #{product_id}"
      puts "  Total quantity: #{inventory[:total_quantity]}"
      puts "  Reserved quantity: #{inventory[:reserved_quantity]}"
      puts "  Available quantity: #{inventory[:available_quantity]}"
      puts "\n  Reservations:"
      if inventory[:reservations].empty?
        puts "    (none)"
      else
        inventory[:reservations].each do |r|
          puts "    - #{r[:reservation_id]}: #{r[:quantity]} units (expires: #{r[:expires_at]})"
        end
      end
    else
      puts "No inventory found for product: #{product_id}"
    end
  end

  desc "List all inventories"
  task list: :environment do
    query_service = InventoryQueryService.new
    inventories = query_service.list_all_inventories

    if inventories.empty?
      puts "No inventories found"
    else
      puts "\nAll Inventories:"
      inventories.each do |inv|
        puts "\n  Product: #{inv[:product_id]}"
        puts "    Total: #{inv[:total_quantity]}, Reserved: #{inv[:reserved_quantity]}, Available: #{inv[:available_quantity]}"
      end
    end
  end
end
