# ES+CQRSとRails Way - アーキテクチャ比較と評価

## 概要

このドキュメントでは、Event Sourcing + CQRSパターンと従来のRails Wayアプローチを比較し、それぞれの利点・欠点、適用すべきケースについて考察します。

## Rails Wayとは何か

Rails Wayは以下の原則に基づいています：

- **Active Recordパターン**: モデルがデータベースレコードと1:1で対応
- **Convention over Configuration**: 設定より規約
- **CRUD中心**: Create/Read/Update/Deleteの操作
- **Fat Models, Skinny Controllers**: ビジネスロジックをモデルに集約
- **RESTful**: リソース指向のアーキテクチャ

### 典型的なRails Wayのコード例

```ruby
# app/models/order.rb
class Order < ApplicationRecord
  belongs_to :customer
  has_many :order_items

  validates :status, inclusion: { in: %w[pending confirmed shipped cancelled] }

  def confirm!
    update!(status: 'confirmed', confirmed_at: Time.current)
  end

  def ship!(tracking_number)
    update!(status: 'shipped', tracking_number: tracking_number, shipped_at: Time.current)
  end
end

# app/controllers/orders_controller.rb
class OrdersController < ApplicationController
  def confirm
    @order = Order.find(params[:id])
    @order.confirm!
    redirect_to @order, notice: 'Order confirmed'
  end
end
```

## ES+CQRSがRails Wayから外れる点

### 1. 状態管理の違い

**Rails Way: 状態を直接更新**
```ruby
order.update!(status: 'confirmed')
```

**ES+CQRS: イベントを記録**
```ruby
# app/domain/orders/order.rb:73-76
record_event(Events::OrderConfirmed.new(
  order_id: id,
  confirmed_at: Time.current
))
```

### 2. 読み書きの分離

**Rails Way: 同じモデルで読み書き**
```ruby
# 書き込み
order.update!(status: 'shipped')

# 読み取り
Order.where(status: 'shipped').order(created_at: :desc)
```

**ES+CQRS: 完全に分離**
```ruby
# 書き込み側: Domain::Orders::Order (集約)
# app/domain/orders/order.rb
class Order < EventSourcing::AggregateRoot
  # ビジネスロジック
end

# 読み取り側: Projections::Models::OrderSummaryReadModel
# app/projections/models/order_summary_read_model.rb
class OrderSummaryReadModel < ApplicationRecord
  # クエリ用に最適化されたモデル
end
```

### 3. ディレクトリ構造

**Rails Way:**
```
app/
├── models/
│   └── order.rb
├── controllers/
│   └── orders_controller.rb
└── views/
    └── orders/
```

**ES+CQRS:**
```
app/
├── domain/                     # ドメイン層（Rails標準にない）
│   └── orders/
│       ├── order.rb           # 集約ルート
│       ├── commands/          # コマンド
│       └── events/            # ドメインイベント
├── projections/               # Read Models（Rails標準にない）
│   ├── models/
│   ├── projectors/
│   └── queries/
└── controllers/
    └── orders_controller.rb
```

### 4. データフロー

**Rails Way:**
```
Client → Controller → Model (read/write) → Database → View
```

**ES+CQRS:**
```
Client → Controller → Command Handler → Aggregate → Event Store
                                                    ↓
                                                Projector
                                                    ↓
Client ← Controller ← Query Service ← Read Models
```

## ES+CQRSの利点

### 1. 完全な監査ログ

すべての状態変更がイベントとして記録されます。

```ruby
# events テーブル
{
  aggregate_id: "ORDER-001",
  event_type: "Domain::Orders::Events::OrderPlaced",
  event_data: {
    order_id: "ORDER-001",
    customer_name: "山田太郎",
    total_amount: 10000
  },
  version: 1,
  occurred_at: "2025-01-01 10:00:00"
}
```

**メリット:**
- "誰が、いつ、何をしたか" が完全に追跡可能
- 法的要件や監査要件への対応が容易
- デバッグやトラブルシューティングが容易

### 2. 時間旅行とイベント再生

過去の任意の時点の状態を復元できます。

```ruby
# 特定のバージョンまでのイベントを再生
events = event_store.get_events(aggregate_id: "ORDER-001")
aggregate.load_from_history(events.take(10))  # 最初の10イベントまで

# 現在の状態
aggregate.load_from_history(events)
```

**メリット:**
- バグの再現が容易
- 過去の状態を分析可能
- タイムトラベルデバッグ

### 3. ビジネスロジックの明確化

ドメインイベントでビジネスの出来事を明示的に表現します。

```ruby
# app/domain/orders/events/
Events::OrderPlaced       # 注文が作成された
Events::OrderItemAdded    # 商品が追加された
Events::OrderConfirmed    # 注文が確定された
Events::OrderShipped      # 注文が発送された
Events::OrderCancelled    # 注文がキャンセルされた
```

**メリット:**
- ビジネスの言葉でコードを記述（ユビキタス言語）
- ドメイン知識がコードに反映される
- ステークホルダーとのコミュニケーションが改善

### 4. 読み取りパフォーマンスの最適化

用途別に最適化されたRead Modelを構築できます。

```ruby
# 一覧表示用（必要最小限のフィールド）
class OrderSummaryReadModel < ApplicationRecord
  # order_id, customer_name, status, total_amount のみ
end

# 詳細表示用（すべてのフィールド）
class OrderDetailsReadModel < ApplicationRecord
  has_many :order_item_read_models
  # すべての詳細情報
end

# 統計分析用
class OrderStatisticsReadModel < ApplicationRecord
  # 集計済みのデータ
end
```

**メリット:**
- クエリパフォーマンスの大幅な向上
- 非正規化によるJOINの削減
- 目的に応じた最適なデータ構造

### 5. スケーラビリティ

書き込みと読み取りを独立にスケールできます。

```ruby
# 書き込み側: 1台のPostgreSQL
Event Store → [PostgreSQL Primary]

# 読み取り側: 複数のデータベース/キャッシュ
Read Models → [PostgreSQL Read Replica 1]
           → [PostgreSQL Read Replica 2]
           → [Redis Cache]
           → [Elasticsearch]
```

**メリット:**
- 読み書きの負荷を独立して調整
- 読み取りに特化したデータベースの選択（Elasticsearch、MongoDBなど）
- 水平スケーリングが容易

### 6. 柔軟なRead Model構築

同じイベントストリームから複数のRead Modelを構築できます。

```ruby
# 新しいRead Modelを追加
class CustomerOrderHistoryReadModel < ApplicationRecord
  # 顧客の注文履歴専用
end

# イベントを再生して構築
rails event_sourcing:rebuild_read_models
```

**メリット:**
- 既存のコードを変更せずに新しいビューを追加
- 異なるクエリパターンに最適化
- A/Bテストやカナリアリリースが容易

## ES+CQRSの欠点

### 1. 複雑性の増加

単純なCRUD操作が複雑なフローになります。

```ruby
# Rails Way (1ステップ)
order.update!(status: 'confirmed')

# ES+CQRS (6ステップ)
Controller
  ↓
Command (Domain::Orders::Commands::ConfirmOrder)
  ↓
CommandHandler (Domain::Orders::OrderCommandHandler)
  ↓
Aggregate (Domain::Orders::Order)
  ↓
Event (Domain::Orders::Events::OrderConfirmed)
  ↓
Projector (Projections::Projectors::OrderSummaryProjector)
  ↓
ReadModel (Projections::Models::OrderSummaryReadModel)
```

**デメリット:**
- ボイラープレートコードが大量に必要
- データフローの追跡が困難
- 簡単な変更にも多くのファイルの修正が必要

### 2. 学習コスト

チーム全体がES+CQRSを理解する必要があります。

```ruby
# 新しい概念
- Event Sourcing
- CQRS
- 集約（Aggregate）
- ドメインイベント
- Projector
- 結果整合性（Eventual Consistency）
- イベントバージョニング
```

**デメリット:**
- オンボーディングに時間がかかる
- Railsの経験があっても学び直しが必要
- チーム全体の合意形成が難しい

### 3. 結果整合性

書き込みと読み取りの間に遅延が発生します。

```ruby
# コマンド実行
$order_command_handler.handle_confirm_order(command)
# ↓ イベント保存
# ↓ Projector実行（非同期の場合）
# ↓ Read Model更新

# この間、Read Modelは古い状態
order = $order_queries.find_order_details(order_id)
order.status  # まだ 'pending' の可能性
```

**デメリット:**
- 即座に読み取れない可能性（Eventually Consistent）
- ユーザー体験への影響（「更新したのに反映されない」）
- 結果整合性を考慮したUI設計が必要

### 4. Rails生態系との不整合

標準的なRailsツールとの相性が悪くなります。

```ruby
# 使えない/使いづらいツール
- rails generate scaffold
- ActiveAdmin（カスタマイズが大量に必要）
- RailsAdmin
- devise（認証をES+CQRSで実装は困難）
- 多くのgem（ActiveRecord前提のもの）
```

**デメリット:**
- 既存のgemが使えない
- カスタム実装が必要
- 開発速度の低下

### 5. ボイラープレートコード

1つの機能に対して多数のファイルが必要です。

```ruby
# 1つのコマンド（注文確定）に必要なファイル
app/domain/orders/commands/confirm_order.rb        # コマンド
app/domain/orders/events/order_confirmed.rb        # イベント
app/domain/orders/order.rb                         # 集約（confirmメソッド）
app/domain/orders/order_command_handler.rb         # ハンドラー
app/projections/projectors/order_summary_projector.rb   # プロジェクター
app/projections/projectors/order_details_projector.rb
app/projections/models/order_summary_read_model.rb      # Read Model
app/projections/models/order_details_read_model.rb
```

**デメリット:**
- ファイル数の爆発的な増加
- コードの重複
- メンテナンスコストの増加

### 6. デバッグの困難さ

問題の原因特定が難しくなります。

```ruby
# Read Modelが正しくない場合
# どこが原因？
- イベントが正しく保存されていない？
- Projectorのバグ？
- イベントの順序問題？
- 並行実行の問題？
- べき等性の問題？
```

**デメリット:**
- 問題の切り分けが複雑
- トラブルシューティングに時間がかかる
- 深いドメイン知識が必要

## ES+CQRSが適しているケース

### 1. 監査要件が厳しいドメイン

**例:**
- 金融システム（銀行、証券、保険）
- 医療システム（電子カルテ、処方箋）
- 法務システム（契約管理、訴訟管理）
- 会計システム

**理由:**
- すべての操作の完全な記録が必要
- 法的要件への対応
- 「誰が、いつ、何をしたか」の証跡

```ruby
# example_1/app/domain/orders/order.rb:37-42
# 注文作成の完全な記録
record_event(Events::OrderPlaced.new(
  order_id: id,
  customer_name: customer_name,
  total_amount: total_amount,
  placed_at: Time.current
))
```

### 2. 複雑なビジネスロジック

**例:**
- 複雑な状態遷移（承認ワークフロー）
- 多数のビジネスルール
- ドメイン駆動設計が有効なドメイン

**理由:**
- ビジネスロジックを集約に集約
- ドメインイベントで明示的なモデリング
- 状態管理の複雑さへの対応

```ruby
# example_1/app/domain/orders/order.rb:45-61
# 複雑なバリデーションとビジネスルール
def add_item(product_name:, quantity:, unit_price:)
  unless can_modify?
    raise InvalidOperationError, "Cannot add items to #{@status} order"
  end

  if quantity <= 0
    raise InvalidOperationError, "Quantity must be positive"
  end

  record_event(Events::OrderItemAdded.new(...))
end
```

### 3. 高度な分析要件

**例:**
- リアルタイムダッシュボード
- ビジネスインテリジェンス
- データマイニング

**理由:**
- イベントストリームから複数のRead Modelを構築
- 異なる集計方法での分析
- 履歴データの再分析

### 4. スケーラビリティが重要

**例:**
- 大規模ECサイト
- ソーシャルメディア
- IoTシステム

**理由:**
- 読み書きの負荷が大きく異なる
- 独立したスケーリングが必要
- 高トラフィックへの対応

## Rails Wayのままで良いケース

### 1. シンプルなCRUDアプリケーション

**例:**
- 社内ツール
- 簡単な管理画面
- プロトタイプ

**理由:**
- 複雑な状態管理が不要
- 監査ログは標準的なログで十分
- 開発速度優先

### 2. 小規模チーム/短期プロジェクト

**例:**
- スタートアップのMVP
- 概念実証（PoC）
- 短期間での検証

**理由:**
- 学習コストをかけられない
- 素早い開発が必要
- 将来的に書き換え可能

### 3. ビジネスロジックが単純

**例:**
- 単純なマスタ管理
- 基本的なCRUD操作のみ
- 状態遷移が少ない

**理由:**
- ES+CQRSの複雑さが不要
- Rails Wayで十分
- オーバーエンジニアリングを避ける

### 4. 既存のRailsアプリケーション

**例:**
- 既存の大規模Railsアプリ
- レガシーシステム

**理由:**
- 移行コストが高い
- リスクが大きい
- 段階的なアプローチの検討

## 実践的なアドバイス

### 1. ハイブリッドアプローチ

すべてをES+CQRSにする必要はありません。重要なドメインのみに適用します。

```ruby
# 重要なドメイン: ES+CQRS
app/domain/orders/         # 注文（ビジネスの中核）
app/domain/payments/       # 支払い（金銭取引）
app/domain/inventory/      # 在庫（複雑な状態管理）

# シンプルなドメイン: Rails Way
app/models/user.rb         # ユーザー（devise使用）
app/models/product.rb      # 商品（基本的なCRUD）
app/models/category.rb     # カテゴリー（マスタデータ）
app/models/tag.rb          # タグ（シンプルな管理）
```

**メリット:**
- 適材適所でアーキテクチャを選択
- 開発効率と品質のバランス
- チームの学習負担を軽減

### 2. 段階的な導入

いきなり完全なES+CQRSにせず、段階的に導入します。

**フェーズ1: 通常のRails Way**
```ruby
class Order < ApplicationRecord
  def confirm!
    update!(status: 'confirmed')
  end
end
```

**フェーズ2: イベントの記録を追加（ハイブリッド）**
```ruby
class Order < ApplicationRecord
  after_update :publish_event

  def confirm!
    update!(status: 'confirmed')
  end

  private

  def publish_event
    EventPublisher.publish(OrderConfirmedEvent.new(self))
  end
end
```

**フェーズ3: Read Modelの導入**
```ruby
class Order < ApplicationRecord
  # 書き込み用
end

class OrderReadModel < ApplicationRecord
  # 読み取り用（Projectorで更新）
end
```

**フェーズ4: 完全なES+CQRS**
```ruby
class Order < EventSourcing::AggregateRoot
  # イベントソーシング
end
```

**メリット:**
- リスクを最小化
- チームの学習曲線に合わせる
- 各段階で評価・改善

### 3. チームの合意形成

**アーキテクチャ決定記録（ADR）を作成**

```markdown
# ADR: 注文ドメインにES+CQRSを採用

## ステータス
承認済み

## コンテキスト
- 注文の完全な監査ログが必要（法的要件）
- 注文処理のビジネスロジックが複雑
- 注文一覧と詳細で異なるクエリパフォーマンスが必要

## 決定
注文ドメインにEvent Sourcing + CQRSを採用する

## 結果
- 利点: 完全な監査ログ、柔軟なRead Model
- 欠点: 複雑性の増加、学習コスト
- 代替案: Rails Way（却下理由：監査要件を満たせない）
```

**定期的なレビュー**
- 四半期ごとにアーキテクチャの評価
- メトリクスの収集（開発速度、バグ率、パフォーマンス）
- チームのフィードバック収集

### 4. ツールと自動化

**コード生成器の作成**
```ruby
# lib/generators/event_sourcing/event/event_generator.rb
rails generate event_sourcing:event Order OrderPlaced order_id customer_name total_amount

# 以下を自動生成
# - app/domain/orders/events/order_placed.rb
# - spec/domain/orders/events/order_placed_spec.rb
```

**テストの自動化**
```ruby
# spec/support/event_sourcing_helpers.rb
RSpec.shared_examples "an event" do
  it { is_expected.to respond_to(:to_h) }
  it { is_expected.to respond_to(:from_h) }
end

# spec/domain/orders/events/order_placed_spec.rb
RSpec.describe Domain::Orders::Events::OrderPlaced do
  it_behaves_like "an event"
end
```

**ドキュメントの自動生成**
```ruby
# イベントカタログの生成
rake event_sourcing:generate_event_catalog
# → docs/event_catalog.md
```

## トレードオフの評価

### コスト vs ベネフィット

| 項目 | Rails Way | ES+CQRS |
|------|-----------|---------|
| **開発速度** | 高速 | 低速 |
| **学習コスト** | 低 | 高 |
| **監査ログ** | 限定的 | 完全 |
| **パフォーマンス（読み取り）** | 中 | 高 |
| **パフォーマンス（書き込み）** | 高 | 中 |
| **スケーラビリティ** | 中 | 高 |
| **複雑性** | 低 | 高 |
| **デバッグ** | 容易 | 困難 |
| **Rails生態系** | 完全対応 | 部分対応 |
| **ビジネスロジック表現** | 暗黙的 | 明示的 |

### 定量的な評価

**開発コスト（例）**
```
Rails Way:
- 新機能追加: 2時間
- バグ修正: 1時間

ES+CQRS:
- 新機能追加: 6時間（3倍）
- バグ修正: 2時間（2倍）
```

**パフォーマンス（例）**
```
Rails Way:
- 注文一覧: 500ms（JOINあり）
- 注文詳細: 200ms

ES+CQRS:
- 注文一覧: 50ms（Read Model、10倍高速）
- 注文詳細: 30ms（非正規化、6倍高速）
```

**監査ログ（例）**
```
Rails Way:
- papertrailなど: 変更履歴のみ
- ビジネスの文脈が不明

ES+CQRS:
- イベントソーシング: すべての操作を記録
- ビジネスの意図が明確
```

## 結論

### Rails Wayを外れることは「悪」ではなく「トレードオフ」

**Rails Wayの強み:**
- 高速な開発
- 豊富なエコシステム
- 低い学習コスト
- シンプルさ

**ES+CQRSの強み:**
- 完全な監査ログ
- 高いスケーラビリティ
- 明示的なビジネスロジック
- 柔軟なRead Model

### example_1の評価

このプロジェクトの実装（example_1/）は以下の点で優れています：

✅ **ActiveRecordを活用**
- 完全に外れていない（PostgreSQLを使用）
- Railsの強みを活かしている

✅ **gemなしでシンプル**
- 外部依存が少ない
- 理解しやすい実装
- カスタマイズが容易

✅ **メタプログラミングなし**
- 明示的なコード
- 追跡しやすい
- デバッグが容易

✅ **明確なレイヤー分離**
- ドメイン層（app/domain/）
- プロジェクション層（app/projections/）
- インフラ層（lib/event_sourcing/）

### 最終的な推奨事項

**ES+CQRSを採用すべき場合:**
1. 監査要件が厳しい
2. ビジネスロジックが複雑
3. 高度な分析が必要
4. スケーラビリティが重要
5. チームが理解・合意している
6. 長期的な運用を想定

**Rails Wayのままで良い場合:**
1. シンプルなCRUDアプリ
2. 小規模チーム/短期プロジェクト
3. ビジネスロジックが単純
4. 監査要件が緩い
5. 素早い開発が必要

**重要なポイント:**
- なぜES+CQRSが必要かを明確にする
- チーム全体が理解・合意している
- コスト（複雑性）> ベネフィット（監査ログ、スケーラビリティ）を定期的に評価
- Rails WayとES+CQRSを適材適所で使い分ける

Rails WayはRailsの強力な武器ですが、すべての問題に最適なわけではありません。ES+CQRSが本当に必要なドメインでは、むしろRails Wayに固執することがリスクになる場合もあります。

**アーキテクチャは手段であり、目的ではありません。**

ビジネス要件、チームの能力、プロジェクトの制約を総合的に判断し、最適なアプローチを選択することが重要です。

---

**作成日**: 2025-10-16
**プロジェクト**: rails_event_sourcing
**バージョン**: 1.0
