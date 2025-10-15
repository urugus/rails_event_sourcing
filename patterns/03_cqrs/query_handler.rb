# frozen_string_literal: true

require_relative 'query'
require_relative 'read_model'

# Queryハンドラの基底クラス
class QueryHandler
  def initialize(connection)
    @connection = connection
  end

  def handle(query)
    raise NotImplementedError, "#{self.class} must implement #handle"
  end

  protected

  attr_reader :connection
end

# 注文詳細クエリハンドラ
class GetOrderHandler < QueryHandler
  def handle(query)
    order = OrderReadModel.find(connection, query.order_id)

    if order
      QueryResult.success(data: order.to_h)
    else
      QueryResult.not_found(message: "Order #{query.order_id} not found")
    end
  end
end

# 顧客の注文一覧クエリハンドラ
class GetCustomerOrdersHandler < QueryHandler
  def handle(query)
    orders = OrderReadModel.find_by_customer(
      connection,
      query.customer_id,
      limit: query.limit,
      offset: query.offset
    )

    QueryResult.success(data: orders.map(&:to_h))
  end
end

# 注文統計クエリハンドラ
class GetOrderStatsHandler < QueryHandler
  def handle(query)
    stats = OrderReadModel.stats(
      connection,
      from_date: query.from_date,
      to_date: query.to_date
    )

    QueryResult.success(data: stats)
  end
end

# 出荷待ち注文クエリハンドラ
class GetPendingShipmentsHandler < QueryHandler
  def handle(query)
    orders = OrderReadModel.find_by_state(
      connection,
      'submitted',
      limit: query.limit
    )

    QueryResult.success(data: orders.map(&:to_h))
  end
end

# クエリ実行結果
class QueryResult
  attr_reader :success, :data, :error

  def initialize(success:, data: nil, error: nil)
    @success = success
    @data = data
    @error = error
  end

  def self.success(data:)
    new(success: true, data: data)
  end

  def self.not_found(message:)
    new(success: false, error: message)
  end

  def self.failure(error:)
    new(success: false, error: error)
  end

  def success?
    @success
  end

  def failure?
    !@success
  end
end
