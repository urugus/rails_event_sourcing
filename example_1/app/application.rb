# frozen_string_literal: true

# アプリケーションのセットアップと依存性の注入
class Application
  attr_reader :event_store, :read_model_store, :order_repository,
              :order_command_handler, :order_queries

  def initialize
    # Event Store（書き込み側）の初期化
    @event_store = EventSourcing::EventStore.new

    # Read Model Store（読み取り側）の初期化
    @read_model_store = Projections::ReadModelStore.new

    # プロジェクターの初期化とイベント購読
    setup_projectors

    # リポジトリの初期化
    @order_repository = EventSourcing::Repository.new(
      event_store: @event_store,
      aggregate_class: Domain::Orders::Order
    )

    # コマンドハンドラーの初期化（書き込み側）
    @order_command_handler = Domain::Orders::OrderCommandHandler.new(
      repository: @order_repository
    )

    # クエリサービスの初期化（読み取り側）
    @order_queries = Projections::Queries::OrderQueries.new(
      read_model_store: @read_model_store
    )
  end

  # すべてのデータをクリアする（テスト用）
  def clear!
    @event_store.clear!
    @read_model_store.clear!
  end

  private

  def setup_projectors
    # 注文サマリープロジェクター
    summary_projector = Projections::Projectors::OrderSummaryProjector.new(
      read_model_store: @read_model_store
    )

    # 注文詳細プロジェクター
    details_projector = Projections::Projectors::OrderDetailsProjector.new(
      read_model_store: @read_model_store
    )

    # イベントストアにプロジェクターを購読させる
    @event_store.subscribe do |event, event_record|
      summary_projector.handle_event(event, event_record)
      details_projector.handle_event(event, event_record)
    end
  end
end
