# Repository Guidelines

## プロジェクト構成とモジュール構成
- ルートには `pattern1_lightweight_cqrs/`, `pattern2_rails_event_store/`, `pattern3_full_event_sourcing/`, `pattern4_activerecord_events/` の4実装が並び、各ディレクトリは独立した Event Sourcing/CQRS のサンプルです。
- Pattern 1 は `models/`, `services/commands/`, `services/queries/`, `controllers/`, `migrations/` が主な構成で、既存 Rails アプリに差し込む想定の軽量 CQRS です。
- Pattern 2 と Pattern 4 は共通して `command_handlers/`, `domain/`, `event_handlers/`, `read_models/`, `queries/`, `migrations/` を揃え、イベントストアの実装のみ (Rails Event Store vs ActiveRecord) が異なります。
- Pattern 3 は `lib/` 配下に `command_handlers`, `commands`, `event_store`, `projectors`, `read_models`, `domain` を収め、純粋 Ruby のリファレンス実装と `example_usage.rb` を提供します。

## ビルド・テスト・開発コマンド
- `cd pattern3_full_event_sourcing && ruby example_usage.rb`: フル Event Sourcing の標準フローを通して動作確認します。
- `find pattern4_activerecord_events -name '*.rb' -print0 | xargs -0 ruby -c`: ActiveRecord 実装の Ruby 構文チェックを一括実行します。
- Rails プロジェクトへ統合する際は対象パターンの `migrations/` をホスト側にコピーし、`bin/rails db:migrate` でスキーマを適用してください。

## コーディングスタイルと命名規約
- Ruby は2スペースインデント・UTF-8・`# frozen_string_literal: true` の維持を基本とし、クラス／モジュールは `CamelCase`、メソッド・ファイルは `snake_case` を徹底します。
- ハンドラや集約は `<コンテキスト>::<役割>` 形式 (例: `CommandHandlers::OpenAccount`) を使い、ドメインイベントは過去形 (例: `MoneyWithdrawn`) で命名します。
- 新規コードは既存の責務別ディレクトリに揃え、読み取り系を `read_models/`、書き込み系を `command_handlers/` や `domain/aggregates/` に配置します。

## コミットとプルリクエスト
- コミットメッセージは英語の命令形で短く保ち、影響範囲を明示するため `pattern4: add account projector` のようにパターン名プレフィックスを推奨します。
- 1コミット1トピックを守り、マイグレーションやサンプルコードの追加時は本文に目的とロールバック手順を記載してください。
- PR では対象パターン、動作確認手順、関連 Issue、必要なスクリーンショットやログを箇条書きにし、README または本ガイドに反映したかどうかをコメントで明示します。

## エージェント向けメモ
- 着手前に該当パターン配下の README を必ず精読し、既存の境界づけコンテキストや命名を崩さない計画を立ててください。
- 複数パターンへ跨る変更は例外的なケースに限定し、影響範囲と移行手順を PR 説明に列挙します。
- 追加したサンプルやスクリプトは冪等性を確保し、README の「使用例」節が古くならないよう必要に応じて更新してください。
