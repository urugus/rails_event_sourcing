# Pattern 1: 軽量 CQRS (Lightweight CQRS)

## 概要
Event Sourcing を使わず、CQRS の概念のみを導入した軽量な実装パターンです。
ActiveRecord を継続使用し、既存の Rails アプリケーションに段階的に導入できます。

## 特徴

### メリット
- 既存の Rails アプリに導入しやすい
- ActiveRecord の機能をそのまま使える
- 学習コストが低い
- 段階的な移行が可能

### デメリット
- イベントの履歴が残らない
- 状態の復元ができない
- 監査ログが別途必要

## アーキテクチャ

```
Controller
    ↓
Command Service (Write)  ←→  ActiveRecord Models  ←→  Query Service (Read)
    ↓                              ↓
  DB Table                      DB Table
```

## 主要コンポーネント

### 1. Models (ActiveRecord)
- `Account`: 口座情報
- `Transaction`: 取引履歴

### 2. Command Services (Write側)
- `Accounts::OpenAccount`: 口座開設
- `Accounts::Deposit`: 入金処理
- `Accounts::Withdraw`: 出金処理

### 3. Query Services (Read側)
- `Accounts::GetBalance`: 残高照会
- `Accounts::GetTransactionHistory`: 取引履歴取得

## ディレクトリ構成

```
pattern1_lightweight_cqrs/
├── README.md
├── models/
│   ├── account.rb
│   └── transaction.rb
├── services/
│   ├── commands/
│   │   ├── open_account.rb
│   │   ├── deposit.rb
│   │   └── withdraw.rb
│   └── queries/
│       ├── get_balance.rb
│       └── get_transaction_history.rb
├── controllers/
│   └── accounts_controller.rb
└── migrations/
    └── 001_create_accounts_and_transactions.rb
```

## 使用例

```ruby
# 口座開設
result = Accounts::Commands::OpenAccount.call(
  account_number: "ACC001",
  owner_name: "山田太郎",
  initial_balance: 10000
)

# 入金
Accounts::Commands::Deposit.call(
  account_number: "ACC001",
  amount: 5000,
  description: "給与振込"
)

# 出金
Accounts::Commands::Withdraw.call(
  account_number: "ACC001",
  amount: 2000,
  description: "ATM出金"
)

# 残高照会
balance = Accounts::Queries::GetBalance.call(account_number: "ACC001")
# => 13000

# 取引履歴
history = Accounts::Queries::GetTransactionHistory.call(
  account_number: "ACC001",
  limit: 10
)
```

## 適用シーン

- CQRS の概念を学びたい
- 既存アプリに段階的に導入したい
- イベント履歴が不要なシンプルなアプリ
- パフォーマンスより開発速度を優先

## 次のステップ

より高度な実装が必要になったら：
- Pattern 2: Rails Event Store でイベント履歴を導入
- Pattern 3: フル Event Sourcing で完全なイベント駆動に移行
