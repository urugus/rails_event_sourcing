# frozen_string_literal: true

# Event Sourcing + CQRS の初期化設定
# Rails起動時にこのファイルが読み込まれ、必要なコンポーネントを初期化します

Rails.application.config.to_prepare do
  # Event Storeの初期化（lib/event_sourcing/から）
  $event_store = EventSourcing::EventStore.new

  # Projectorsの初期化
  summary_projector = Projections::Projectors::OrderSummaryProjector.new
  details_projector = Projections::Projectors::OrderDetailsProjector.new

  # イベント購読の設定
  # Event Storeに保存されたイベントは自動的にProjectorsに通知される
  $event_store.subscribe do |event, event_record|
    # 各Projectorでイベントを処理し、Read Modelを更新
    summary_projector.handle_event(event, event_record)
    details_projector.handle_event(event, event_record)
  end

  # リポジトリの初期化（集約の永続化を担当）
  $order_repository = EventSourcing::Repository.new(
    event_store: $event_store,
    aggregate_class: Domain::Orders::Order
  )

  # コマンドハンドラーの初期化（書き込み側）
  $order_command_handler = Domain::Orders::OrderCommandHandler.new(
    repository: $order_repository
  )

  # クエリサービスの初期化（読み取り側）
  $order_queries = Projections::Queries::OrderQueries.new
end
