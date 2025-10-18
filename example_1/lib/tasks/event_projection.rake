namespace :event_sourcing do
  desc "未投影イベントを処理してリードモデルを更新する"
  task project: :environment do
    projector_runner = Projections::ProjectorRunner.new(
      [
        Projections::Projectors::OrderSummaryProjector.new,
        Projections::Projectors::OrderDetailsProjector.new
      ]
    )

    runner = Projections::EventProjectionRunner.new(
      event_mappings: Orders::EventMappings.build,
      projector_runner: projector_runner
    )

    runner.call
  end
end
