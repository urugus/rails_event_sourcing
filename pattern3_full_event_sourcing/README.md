# Pattern 3: フル Event Sourcing (Full Event Sourcing)

## 概要
ActiveRecord を使わない、純粋な Event Sourcing の参考実装です。
全ての状態をイベントから復元し、完全なイベント駆動アーキテクチャを実現します。

## 特徴

### メリット
- 完全なイベント駆動設計
- フレームワークに依存しない
- イベントが唯一の真実の源泉
- 高度なドメインモデリングが可能
- タイムトラベル・リプレイが容易

### デメリット
- 実装の複雑さが高い
- 学習コストが非常に高い
- インフラの要件が高い
- 小規模プロジェクトには過剰

## アーキテクチャ

```
Controller
    ↓
Command Handler
    ↓
Aggregate Root (Pure Domain Logic)
    ↓
Domain Events → Event Store (イベントのみ永続化)
    ↓
Event Handlers / Projectors
    ↓
Read Models (別のDB・キャッシュ等)
```

## 主要コンポーネント

### 1. Event Store (自作実装)
- イベントの永続化
- イベントの取得
- ストリーム管理

### 2. Domain Events (Pure Ruby)
- フレームワークに依存しない
- 不変オブジェクト

### 3. Aggregate Root (Pure Ruby)
- ビジネスロジックのみ
- イベントから状態を復元
- ActiveRecordを使用しない

### 4. Command/Query 完全分離
- Commandは非同期処理可能
- Queryは最適化されたRead Model

### 5. Read Models (任意のストレージ)
- Redis, Elasticsearch, PostgreSQL など
- 用途に応じた最適なストレージ選択

## ディレクトリ構成

```
pattern3_full_event_sourcing/
├── README.md
├── lib/
│   ├── event_store/
│   │   ├── event_store.rb        # Event Store実装
│   │   ├── event.rb              # イベント基底クラス
│   │   └── stream.rb             # ストリーム管理
│   ├── domain/
│   │   ├── events/
│   │   │   ├── account_opened.rb
│   │   │   ├── money_deposited.rb
│   │   │   └── money_withdrawn.rb
│   │   ├── aggregates/
│   │   │   └── account.rb
│   │   └── repository.rb          # Aggregate Repository
│   ├── commands/
│   │   ├── command.rb             # コマンド基底クラス
│   │   ├── open_account.rb
│   │   ├── deposit_money.rb
│   │   └── withdraw_money.rb
│   ├── command_handlers/
│   │   ├── open_account_handler.rb
│   │   ├── deposit_money_handler.rb
│   │   └── withdraw_money_handler.rb
│   ├── projectors/
│   │   └── account_balance_projector.rb
│   └── read_models/
│       └── account_balance_repository.rb
└── example_usage.rb
```

## 使用例

```ruby
# Event Store の初期化
event_store = EventStore::InMemoryEventStore.new

# Repository の初期化
repository = Domain::Repository.new(event_store)

# コマンドハンドラの初期化
open_account_handler = CommandHandlers::OpenAccountHandler.new(repository)
deposit_handler = CommandHandlers::DepositMoneyHandler.new(repository)

# 口座開設
command = Commands::OpenAccount.new(
  account_id: "acc-001",
  owner_name: "山田太郎",
  initial_balance: 10000
)
open_account_handler.handle(command)

# 入金
command = Commands::DepositMoney.new(
  account_id: "acc-001",
  amount: 5000,
  description: "給与振込"
)
deposit_handler.handle(command)

# Aggregate から現在の状態を取得
account = repository.load("acc-001", Domain::Aggregates::Account)
puts account.balance # => 15000

# イベント履歴を取得
events = event_store.get_stream("Account-acc-001")
events.each do |event|
  puts "#{event.event_type}: #{event.data}"
end
```

## 実装の特徴

### イベントストアの実装
- イン���モリ実装（例）
- PostgreSQL / EventStoreDB への切り替え可能
- イベントのバージョニング
- スナップショット機能

### ドメインモデルの純粋性
- Railsへの依存なし
- テストが容易
- 再利用可能

### Read Model の柔軟性
- Redis でキャッシュ
- Elasticsearch で検索
- PostgreSQL で集計

## 適用シーン

- 超大規模システム
- 複雑なドメインロジック
- 高いスケーラビリティが必要
- イベント駆動マイクロサービス
- ドメイン駆動設計を徹底したい

## パフォーマンス最適化

### スナップショット
- 定期的にAggregateの状態を保存
- イベントリプレイの高速化

### 非同期処理
- イベント発行後、即座にレスポンス
- Projectorは非同期で処理

### CQRS の徹底
- Writeは最小限の処理
- Readは完全に最適化

## 実装のベストプラクティス

1. **イベントは不変**
   - 一度発行したイベントは変更しない

2. **バージョニング**
   - イベントスキーマの変更は新バージョンを作成

3. **冪等性**
   - 同じイベントを複数回処理しても安全

4. **順序保証**
   - 同一ストリーム内のイベント順序を保証

5. **エラーハンドリング**
   - イベント処理失敗時のリトライ戦略

## 移行戦略

既存システムからの移行：
1. Pattern 1 から開始（CQRS のみ）
2. Pattern 2 で Event Sourcing 導入
3. Pattern 3 で完全なイベント駆動へ

## 参考リソース

- BankSimplistic: https://github.com/cavalle/banksimplistic
- EventStore: https://eventstore.com/
- Sequent Framework: https://sequent.io/
