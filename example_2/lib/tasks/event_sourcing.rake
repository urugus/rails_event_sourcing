namespace :event_sourcing do
  desc "Run projections for all events"
  task project: :environment do
    puts "Starting projection..."
    Projections::Container.projection_manager.call
    puts "Projection completed"
  end

  desc "Retry failed projections"
  task retry_failed: :environment do
    puts "Retrying failed projections..."
    Projections::Container.projection_manager.retry_failed_projections
    puts "Retry completed"
  end

  desc "Show projection status"
  task status: :environment do
    puts "\n=== Projection Positions ==="
    Projections::Models::ProjectionPosition.order(:projector_name).each do |position|
      puts "  #{position.projector_name}: event_id=#{position.last_event_id} (#{position.last_processed_at})"
    end

    puts "\n=== Projection Errors ==="
    errors = Projections::Models::ProjectionError.order(created_at: :desc).limit(10)
    if errors.empty?
      puts "  No errors"
    else
      errors.each do |error|
        puts "  [#{error.projector_name}] event_id=#{error.event_id} retry_count=#{error.retry_count}"
        puts "    Error: #{error.error_message}"
        puts "    Next retry: #{error.next_retry_at}"
        puts ""
      end
    end
  end

  desc "Reset projection position for a specific projector"
  task :reset_position, [:projector_name] => :environment do |_t, args|
    projector_name = args[:projector_name]

    unless projector_name
      puts "Usage: rake event_sourcing:reset_position[projector_name]"
      puts "Example: rake event_sourcing:reset_position[order_summary_projector]"
      exit 1
    end

    position = Projections::Models::ProjectionPosition.find_by(projector_name: projector_name)

    if position
      position.update!(last_event_id: 0, last_processed_at: nil)
      puts "Reset position for #{projector_name}"
    else
      puts "No position found for #{projector_name}"
    end
  end

  desc "Clear projection errors for a specific projector"
  task :clear_errors, [:projector_name] => :environment do |_t, args|
    projector_name = args[:projector_name]

    unless projector_name
      puts "Usage: rake event_sourcing:clear_errors[projector_name]"
      puts "Example: rake event_sourcing:clear_errors[order_summary_projector]"
      exit 1
    end

    count = Projections::Models::ProjectionError.where(projector_name: projector_name).delete_all
    puts "Cleared #{count} errors for #{projector_name}"
  end
end
