# frozen_string_literal: true

# Queryの基底クラス
# Queryは「何を知りたいか」を表現する（副作用なし）
class Query
  attr_reader :query_id

  def initialize
    @query_id = SecureRandom.uuid
  end

  def query_name
    self.class.name
  end
end

# 注文関連のクエリ

# 注文の詳細を取得
class GetOrderQuery < Query
  attr_reader :order_id

  def initialize(order_id:)
    super()
    @order_id = order_id
  end
end

# 顧客の注文一覧を取得
class GetCustomerOrdersQuery < Query
  attr_reader :customer_id, :limit, :offset

  def initialize(customer_id:, limit: 10, offset: 0)
    super()
    @customer_id = customer_id
    @limit = limit
    @offset = offset
  end
end

# 注文の統計情報を取得
class GetOrderStatsQuery < Query
  attr_reader :from_date, :to_date

  def initialize(from_date: nil, to_date: nil)
    super()
    @from_date = from_date || (Time.now - 30 * 24 * 60 * 60)
    @to_date = to_date || Time.now
  end
end

# 出荷待ちの注文を取得
class GetPendingShipmentsQuery < Query
  attr_reader :limit

  def initialize(limit: 50)
    super()
    @limit = limit
  end
end
