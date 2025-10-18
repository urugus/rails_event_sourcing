# 注文ドメインで学ぶ Event Sourcing + CQRS 実装例

Rails 標準機能のみを用いて Event Sourcing と CQRS を組み合わせたサンプル実装です。題材として「注文」ドメインを扱い、gem やメタプログラミング、グローバル変数を使用せずに構成しています。

## 実装のポイント

- **Event Store**: ActiveRecord ベースの `event_records` テーブルに全イベントを保存します。楽観的ロックで同時書き込みを保護します。
- **ドメイン層 (コマンド側)**: `Orders::Order` 集約がビジネスルールを保持し、発生したイベントを `Orders::OrderRepository` が永続化します。
- **プロジェクション (クエリ側)**: Projector がイベントを受け取り、`order_summary_read_models` と `order_details_read_models` の 2 種類のリードモデルを更新します。投影は同期ではなく、バッチ処理で実行します。
- **REST API**: `OrdersController` がコマンド操作とクエリ操作をエンドポイントとして公開します。

## ディレクトリ構成

```
example_1/
├── app/
│   ├── controllers/          # REST API
│   ├── domain/orders/        # 集約・リポジトリ・イベント
│   ├── event_sourcing/       # Event Store
│   └── projections/          # Projector とリードモデル
├── config/routes.rb          # ルーティング
└── db/migrate/               # Event Store とリードモデル用マイグレーション
```

## 動作手順

1. Rails プロジェクトに `example_1/app`, `config`, `db` をコピーします。
2. `config/routes.rb` の内容を既存のルーティングへ統合します。
3. マイグレーションを実行します。

```bash
bin/rails db:migrate
```

4. サーバーを起動します。

```bash
bin/rails server
```

5. 未投影のイベントを処理します（開発環境では手動実行で OK）。

```bash
bin/rails event_sourcing:project
```

本番では cron 等で `bin/rails event_sourcing:project` を定期実行し、未投影イベントを処理してください。

```
*/5 * * * * cd /path/to/app && bin/rails event_sourcing:project
```

## API エンドポイント例

```bash
# 注文作成
curl -X POST http://localhost:3000/orders \
  -H "Content-Type: application/json" \
  -d '{"order":{"customer_name":"山田太郎"}}'

# 商品追加
curl -X POST http://localhost:3000/orders/{order_id}/add_item \
  -H "Content-Type: application/json" \
  -d '{"order_item":{"product_name":"ノートPC","quantity":1,"unit_price_cents":120000}}'

# 注文一覧
curl http://localhost:3000/orders

# 注文詳細
curl http://localhost:3000/orders/{order_id}
```

## 補足

- Event Store はイベントを永続化するだけで即座に投影は行いません。`event_sourcing:project` タスクが `projected_at` が空のイベントだけを順に処理します。
- Projector の実体は純粋な Ruby クラスなので、バッチの並列実行が必要な場合は `EventProjectionRunner` の `batch_size` や cron 間隔を調整してください。
- Event Store は `Orders::EventMappings.build` で登録されたイベントのみを扱います。新しいイベントを追加する際はマッピングを必ず更新してください。
- gem や DSL に頼らず、すべて通常の Ruby クラスとして構築しているため、ビジネスルールのトレースが容易です。
