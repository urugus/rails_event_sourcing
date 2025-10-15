# frozen_string_literal: true

require_relative 'projection'
require_relative '../03_cqrs/read_model'

# 注文サマリーのProjection
# イベントから OrderReadModel を生成・更新
class OrderSummaryProjection < Projection
  def project(event)
    case event.event_type
    when 'OrderCreated'
      on_order_created(event)
    when 'OrderSubmitted'
      on_order_submitted(event)
    when 'OrderShipped'
      on_order_shipped(event)
    when 'OrderCancelled'
      on_order_cancelled(event)
    when 'OrderItemAdded'
      on_order_item_added(event)
    when 'OrderItemRemoved'
      on_order_item_removed(event)
    end
  end

  def clear
    @connection.exec('TRUNCATE TABLE order_read_models')
  end

  private

  def on_order_created(event)
    data = parse_event_data(event)

    @connection.exec_params(
      'INSERT INTO order_read_models
         (order_id, customer_id, total, item_count, state, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7)',
      [
        extract_order_id(event.stream_id),
        data['customer_id'],
        data['total'],
        data['items']&.size || 0,
        'created',
        event.created_at,
        event.created_at
      ]
    )
  end

  def on_order_submitted(event)
    order_id = extract_order_id(event.stream_id)

    @connection.exec_params(
      'UPDATE order_read_models
       SET state = $1, updated_at = $2
       WHERE order_id = $3',
      ['submitted', Time.now, order_id]
    )
  end

  def on_order_shipped(event)
    order_id = extract_order_id(event.stream_id)
    data = parse_event_data(event)

    @connection.exec_params(
      'UPDATE order_read_models
       SET state = $1, tracking_number = $2, updated_at = $3
       WHERE order_id = $4',
      ['shipped', data['tracking_number'], Time.now, order_id]
    )
  end

  def on_order_cancelled(event)
    order_id = extract_order_id(event.stream_id)

    @connection.exec_params(
      'UPDATE order_read_models
       SET state = $1, updated_at = $2
       WHERE order_id = $3',
      ['cancelled', Time.now, order_id]
    )
  end

  def on_order_item_added(event)
    order_id = extract_order_id(event.stream_id)
    data = parse_event_data(event)

    # 合計金額と商品数を再計算
    @connection.exec_params(
      'UPDATE order_read_models
       SET total = total + $1,
           item_count = item_count + 1,
           updated_at = $2
       WHERE order_id = $3',
      [data['quantity'] * data['price'], Time.now, order_id]
    )
  end

  def on_order_item_removed(event)
    order_id = extract_order_id(event.stream_id)

    # 簡易実装: item_countのみ減らす
    @connection.exec_params(
      'UPDATE order_read_models
       SET item_count = item_count - 1,
           updated_at = $1
       WHERE order_id = $2',
      [Time.now, order_id]
    )
  end

  def extract_order_id(stream_id)
    stream_id.sub('Order-', '')
  end

  def parse_event_data(event)
    event.data.is_a?(String) ? JSON.parse(event.data) : event.data
  end
end
