# frozen_string_literal: true

# すべての必要なファイルを読み込む
require_relative "app/event_sourcing/event"
require_relative "app/event_sourcing/event_store"
require_relative "app/event_sourcing/aggregate_root"
require_relative "app/event_sourcing/repository"

require_relative "app/domain/orders/events/order_placed"
require_relative "app/domain/orders/events/order_item_added"
require_relative "app/domain/orders/events/order_confirmed"
require_relative "app/domain/orders/events/order_cancelled"
require_relative "app/domain/orders/events/order_shipped"
require_relative "app/domain/orders/order"
require_relative "app/domain/orders/order_command_handler"

require_relative "app/commands/command"
require_relative "app/domain/orders/commands/place_order"
require_relative "app/domain/orders/commands/add_order_item"
require_relative "app/domain/orders/commands/confirm_order"
require_relative "app/domain/orders/commands/cancel_order"
require_relative "app/domain/orders/commands/ship_order"

require_relative "app/projections/read_model_store"
require_relative "app/projections/order_summary"
require_relative "app/projections/order_details"
require_relative "app/projections/projectors/order_summary_projector"
require_relative "app/projections/projectors/order_details_projector"
require_relative "app/projections/queries/order_queries"

require_relative "app/application"

# Time.currentのシミュレーション（Railsがない環境用）
class Time
  def self.current
    Time.now
  end
end

puts "=" * 80
puts "Event Sourcing + CQRS 実装例"
puts "=" * 80
puts

# アプリケーションの初期化
app = Application.new

# === コマンド側（書き込み）: 注文の作成 ===
puts "【1】注文を作成"
puts "-" * 80

place_order_cmd = Domain::Orders::Commands::PlaceOrder.new(
  order_id: "ORDER-001",
  customer_name: "山田太郎",
  total_amount: 10000
)
app.order_command_handler.handle_place_order(place_order_cmd)
puts "✓ 注文が作成されました: ORDER-001"
puts

# === コマンド側: 商品の追加 ===
puts "【2】商品を追加"
puts "-" * 80

add_item_cmd1 = Domain::Orders::Commands::AddOrderItem.new(
  order_id: "ORDER-001",
  product_name: "ノートPC",
  quantity: 1,
  unit_price: 80000
)
app.order_command_handler.handle_add_order_item(add_item_cmd1)
puts "✓ 商品を追加: ノートPC x 1"

add_item_cmd2 = Domain::Orders::Commands::AddOrderItem.new(
  order_id: "ORDER-001",
  product_name: "マウス",
  quantity: 2,
  unit_price: 1500
)
app.order_command_handler.handle_add_order_item(add_item_cmd2)
puts "✓ 商品を追加: マウス x 2"
puts

# === クエリ側（読み取り）: 注文詳細の取得 ===
puts "【3】注文詳細を照会（Read Model）"
puts "-" * 80

order_details = app.order_queries.find_order_details("ORDER-001")
puts "注文ID: #{order_details[:order_id]}"
puts "顧客名: #{order_details[:customer_name]}"
puts "ステータス: #{order_details[:status]}"
puts "商品:"
order_details[:items].each do |item|
  puts "  - #{item[:product_name]} x #{item[:quantity]} @ ¥#{item[:unit_price]} = ¥#{item[:subtotal]}"
end
puts "商品合計: ¥#{order_details[:items_total]}"
puts

# === コマンド側: 注文の確定 ===
puts "【4】注文を確定"
puts "-" * 80

confirm_cmd = Domain::Orders::Commands::ConfirmOrder.new(
  order_id: "ORDER-001"
)
app.order_command_handler.handle_confirm_order(confirm_cmd)
puts "✓ 注文が確定されました"
puts

# === クエリ側: 注文サマリーの取得 ===
puts "【5】注文サマリーを照会（Read Model）"
puts "-" * 80

order_summary = app.order_queries.find_order_summary("ORDER-001")
puts "注文ID: #{order_summary[:order_id]}"
puts "顧客名: #{order_summary[:customer_name]}"
puts "ステータス: #{order_summary[:status]}"
puts "作成日時: #{order_summary[:placed_at]}"
puts "確定日時: #{order_summary[:confirmed_at]}"
puts

# === コマンド側: 注文の発送 ===
puts "【6】注文を発送"
puts "-" * 80

ship_cmd = Domain::Orders::Commands::ShipOrder.new(
  order_id: "ORDER-001",
  tracking_number: "TRACK-12345678"
)
app.order_command_handler.handle_ship_order(ship_cmd)
puts "✓ 注文が発送されました"
puts

# === クエリ側: 発送済み注文の検索 ===
puts "【7】発送済み注文を検索（Read Model）"
puts "-" * 80

shipped = app.order_queries.shipped_orders
puts "発送済み注文: #{shipped.length}件"
shipped.each do |order|
  puts "  - #{order[:order_id]}: #{order[:customer_name]} (追跡番号: #{order[:tracking_number]})"
end
puts

# === 別の注文を作成してキャンセル ===
puts "【8】別の注文を作成してキャンセル"
puts "-" * 80

place_order_cmd2 = Domain::Orders::Commands::PlaceOrder.new(
  order_id: "ORDER-002",
  customer_name: "佐藤花子",
  total_amount: 5000
)
app.order_command_handler.handle_place_order(place_order_cmd2)
puts "✓ 注文が作成されました: ORDER-002"

cancel_cmd = Domain::Orders::Commands::CancelOrder.new(
  order_id: "ORDER-002",
  reason: "顧客都合によるキャンセル"
)
app.order_command_handler.handle_cancel_order(cancel_cmd)
puts "✓ 注文がキャンセルされました"
puts

# === クエリ側: すべての注文を取得 ===
puts "【9】すべての注文を照会（Read Model）"
puts "-" * 80

all_orders = app.order_queries.all_orders
puts "注文数: #{all_orders.length}件"
all_orders.each do |order|
  puts "  - #{order[:order_id]}: #{order[:customer_name]} [#{order[:status]}]"
end
puts

# === イベントストアの中身を確認 ===
puts "【10】保存されたイベントを確認（Event Store）"
puts "-" * 80

all_events = app.event_store.all_events
puts "イベント総数: #{all_events.length}件"
all_events.each do |event_record|
  puts "  - #{event_record[:event_type].split('::').last} (#{event_record[:aggregate_id]}) v#{event_record[:version]}"
end
puts

puts "=" * 80
puts "完了！"
puts "=" * 80
puts
puts "【このサンプルで実証されたこと】"
puts "1. コマンド（書き込み）とクエリ（読み取り）の完全な分離（CQRS）"
puts "2. すべての状態変更がイベントとして保存（Event Sourcing）"
puts "3. イベントから集約を復元可能"
puts "4. 複数のRead Modelを同じイベントから構築"
puts "5. 最適化されたクエリ用のデータ構造"
puts "=" * 80
