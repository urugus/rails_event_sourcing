# frozen_string_literal: true

require 'json'

# Read Modelの基底クラス
# イベントから構築される読み取り専用のビュー
class ReadModel
  def self.table_name
    raise NotImplementedError
  end

  def self.create_table(connection)
    raise NotImplementedError
  end
end

# 注文のRead Model
class OrderReadModel < ReadModel
  attr_accessor :order_id, :customer_id, :total, :item_count, :state,
                :created_at, :updated_at, :tracking_number

  def initialize(attrs = {})
    attrs.each do |key, value|
      send("#{key}=", value) if respond_to?("#{key}=")
    end
  end

  def self.table_name
    'order_read_models'
  end

  def self.create_table(connection)
    connection.exec(<<~SQL)
      CREATE TABLE IF NOT EXISTS #{table_name} (
        order_id VARCHAR(255) PRIMARY KEY,
        customer_id INTEGER NOT NULL,
        total DECIMAL(10, 2) NOT NULL,
        item_count INTEGER NOT NULL DEFAULT 0,
        state VARCHAR(50) NOT NULL,
        tracking_number VARCHAR(255),
        created_at TIMESTAMP NOT NULL,
        updated_at TIMESTAMP NOT NULL
      );

      CREATE INDEX IF NOT EXISTS idx_order_read_models_customer_id
        ON #{table_name}(customer_id);
      CREATE INDEX IF NOT EXISTS idx_order_read_models_state
        ON #{table_name}(state);
      CREATE INDEX IF NOT EXISTS idx_order_read_models_created_at
        ON #{table_name}(created_at);
    SQL
  end

  def self.find(connection, order_id)
    result = connection.exec_params(
      "SELECT * FROM #{table_name} WHERE order_id = $1",
      [order_id]
    )

    return nil if result.ntuples.zero?

    from_db(result[0])
  end

  def self.find_by_customer(connection, customer_id, limit: 10, offset: 0)
    result = connection.exec_params(
      "SELECT * FROM #{table_name}
       WHERE customer_id = $1
       ORDER BY created_at DESC
       LIMIT $2 OFFSET $3",
      [customer_id, limit, offset]
    )

    result.map { |row| from_db(row) }
  end

  def self.find_by_state(connection, state, limit: 50)
    result = connection.exec_params(
      "SELECT * FROM #{table_name}
       WHERE state = $1
       ORDER BY created_at ASC
       LIMIT $2",
      [state, limit]
    )

    result.map { |row| from_db(row) }
  end

  def self.stats(connection, from_date:, to_date:)
    result = connection.exec_params(
      "SELECT
         COUNT(*) as total_orders,
         SUM(total) as total_revenue,
         AVG(total) as average_order_value,
         COUNT(CASE WHEN state = 'shipped' THEN 1 END) as shipped_orders,
         COUNT(CASE WHEN state = 'cancelled' THEN 1 END) as cancelled_orders
       FROM #{table_name}
       WHERE created_at BETWEEN $1 AND $2",
      [from_date, to_date]
    )

    result[0]
  end

  def save(connection)
    connection.exec_params(
      "INSERT INTO #{self.class.table_name}
         (order_id, customer_id, total, item_count, state, tracking_number, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (order_id) DO UPDATE SET
         customer_id = EXCLUDED.customer_id,
         total = EXCLUDED.total,
         item_count = EXCLUDED.item_count,
         state = EXCLUDED.state,
         tracking_number = EXCLUDED.tracking_number,
         updated_at = EXCLUDED.updated_at",
      [order_id, customer_id, total, item_count, state, tracking_number,
       created_at, updated_at]
    )
  end

  def self.from_db(row)
    new(
      order_id: row['order_id'],
      customer_id: row['customer_id'].to_i,
      total: row['total'].to_f,
      item_count: row['item_count'].to_i,
      state: row['state'],
      tracking_number: row['tracking_number'],
      created_at: row['created_at'],
      updated_at: row['updated_at']
    )
  end

  def to_h
    {
      order_id: order_id,
      customer_id: customer_id,
      total: total,
      item_count: item_count,
      state: state,
      tracking_number: tracking_number,
      created_at: created_at,
      updated_at: updated_at
    }
  end
end
