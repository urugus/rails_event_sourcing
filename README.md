# Rails Event Sourcing + CQRS 実装例

RailsでEvent SourcingとCQRSパターンを実装する実践的なコード例です。

## 概要

このリポジトリには、Rails環境でEvent SourcingとCQRSを実装する完全なコード例が含まれています。

- **ActiveRecordベース**: PostgreSQLなどのRDBMSで動作する本番環境対応の実装
- **gemなし**: 外部ライブラリに依存しない、シンプルで理解しやすい実装
- **メタプログラミングなし**: 明示的で追跡しやすいコード

## プロジェクト構成

```
rails_event_sourcing/
├── example_1/                    # 完全な実装例
│   ├── app/                      # アプリケーションコード
│   │   ├── controllers/          # REST APIコントローラー
│   │   ├── domain/               # ドメイン層（書き込み側）
│   │   ├── event_sourcing/       # Event Sourcingインフラ
│   │   └── projections/          # 読み取り側（CQRS）
│   ├── config/                   # 設定ファイル
│   ├── db/migrate/               # マイグレーション
│   └── README.md                 # 詳細なドキュメント
│
├── README.md                     # このファイル
└── ACTIVERECORD_IMPLEMENTATION.md # ActiveRecord実装の詳細ガイド
```

## 実装の詳細

完全な実装とドキュメントは **[example_1/](example_1/)** ディレクトリにあります。

```bash
cd example_1
```

詳しくは [example_1/README.md](example_1/README.md) を参照してください。

## 主要な機能

### Event Sourcing

- すべての状態変更をイベントとしてPostgreSQLに永続化
- イベントを再生して集約の状態を復元
- 完全な監査ログ

### CQRS (Command Query Responsibility Segregation)

- **書き込み側（コマンド）**: ビジネスロジックを実行し、イベントを生成
- **読み取り側（クエリ）**: 最適化されたRead Modelで高速なクエリを提供

### 実装されている機能

- 注文の作成、商品追加、確定、キャンセル、発送
- REST API エンドポイント
- ActiveRecord Read Models
- イベント駆動のProjectors
- クエリサービス

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────┐
│                      Client                             │
└───────────┬─────────────────────────┬───────────────────┘
            │                         │
    ┌───────▼────────┐        ┌──────▼──────────┐
    │  POST /orders  │        │   GET /orders   │
    │   (コマンド)    │        │   (クエリ)       │
    └───────┬────────┘        └──────┬──────────┘
            │                         │
    ┌───────▼────────────┐    ┌──────▼──────────────┐
    │ Command Handler    │    │  Query Service      │
    └───────┬────────────┘    └──────┬──────────────┘
            │                         │
    ┌───────▼────────────┐            │
    │  Order Aggregate   │            │
    │ (ビジネスロジック)  │            │
    └───────┬────────────┘            │
            │                         │
    ┌───────▼────────────┐    ┌──────▼──────────────┐
    │  Event Store (DB)  │    │ Read Models (DB)    │
    └───────┬────────────┘    └─────────────────────┘
            │
    ┌───────▼────────────┐
    │    Projectors      │
    └───────┬────────────┘
            │
    ┌───────▼────────────┐
    │ Read Models (DB)   │
    └────────────────────┘
```

## データベーススキーマ

### Event Store

```sql
CREATE TABLE events (
  id SERIAL PRIMARY KEY,
  aggregate_id VARCHAR NOT NULL,
  aggregate_type VARCHAR NOT NULL,
  event_type VARCHAR NOT NULL,
  event_data JSONB NOT NULL,
  version INTEGER NOT NULL,
  occurred_at TIMESTAMP NOT NULL,
  UNIQUE(aggregate_id, aggregate_type, version)
);
```

### Read Models

- `order_summary_read_models` - 注文一覧用
- `order_details_read_models` - 注文詳細用
- `order_item_read_models` - 注文商品

## セットアップ

### 1. example_1/ ディレクトリに移動

```bash
cd example_1
```

### 2. データベースのマイグレーション

```bash
rails db:migrate
```

### 3. Railsサーバーの起動

```bash
rails server
```

## API使用例

### 注文を作成

```bash
curl -X POST http://localhost:3000/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customer_name": "山田太郎",
    "total_amount": 10000
  }'
```

### 商品を追加

```bash
curl -X POST http://localhost:3000/orders/{order_id}/add_item \
  -H "Content-Type: application/json" \
  -d '{
    "product_name": "ノートPC",
    "quantity": 1,
    "unit_price": 80000
  }'
```

### 注文一覧を取得

```bash
curl http://localhost:3000/orders
```

### 注文詳細を取得

```bash
curl http://localhost:3000/orders/{order_id}
```

## 主要コンポーネント

### 1. ドメイン層（書き込み側）

**Order集約** (`app/domain/orders/order.rb`):
- 注文に関するすべてのビジネスロジック
- コマンドを受け取り、イベントを生成
- ビジネスルールの検証

**コマンドハンドラー** (`app/domain/orders/order_command_handler.rb`):
- コマンドを受け取り、集約に対する操作を実行
- トランザクション境界を定義

### 2. Event Store

**ActiveRecord Event Store** (`app/event_sourcing/ar_event_store.rb`):
- PostgreSQLにイベントを永続化
- 楽観的ロックによる並行制御
- イベント購読機能

### 3. 読み取り側（CQRS）

**Read Models** (`app/projections/models/`):
- クエリ用に最適化されたActiveRecordモデル
- 非正規化されたデータ構造

**Projectors** (`app/projections/projectors/`):
- イベントを購読してRead Modelを更新
- べき等な処理で再実行可能

**Query Service** (`app/projections/queries/`):
- Read Modelへのアクセスを提供
- 複雑なクエリをカプセル化

## Event SourcingとCQRSの利点

### Event Sourcingの利点

1. **完全な監査ログ**: すべての変更が記録される
2. **時間旅行**: 過去の任意の時点の状態を復元可能
3. **イベント駆動**: イベントを他のサービスに配信可能
4. **柔軟なRead Model**: 同じイベントから複数のRead Modelを構築
5. **デバッグが容易**: イベントを再生して問題を再現

### CQRSの利点

1. **読み取りの最適化**: クエリ専用のデータ構造で高速化
2. **スケーラビリティ**: 読み取りと書き込みを独立にスケール
3. **複雑性の分離**: ビジネスロジックとクエリロジックを分離
4. **柔軟性**: 異なるストレージ技術を使用可能

## ドキュメント

- **[example_1/README.md](example_1/README.md)** - 完全な実装の詳細とAPI使用例
- **[ACTIVERECORD_IMPLEMENTATION.md](ACTIVERECORD_IMPLEMENTATION.md)** - ActiveRecord実装の詳細ガイド

## 本番環境での運用

### Read Modelの再構築

イベントを再生してRead Modelを再構築できます：

```bash
rails event_sourcing:rebuild_read_models
```

### 非同期イベント処理

大量のイベントを処理する場合、Sidekiqなどを使ってProjectorsを非同期で実行できます。

### スナップショット

多数のイベントを持つ集約の復元を高速化するために、定期的にスナップショットを保存できます。

## まとめ

この実装により：

- ✅ RailsでEvent Sourcingを実践的に適用
- ✅ CQRSパターンで読み書きを分離
- ✅ ActiveRecordで本番環境対応
- ✅ gemなしのシンプルな実装
- ✅ 完全な監査ログとイベント履歴
- ✅ スケーラブルなアーキテクチャ

Event SourcingとCQRSの本質を理解し、Railsアプリケーションに適用する方法を学べます。
