# 読解ログ - ChatwootにおけるActionCableの実装

## 1. セッション概要
- 日付/時間: 2025-07-30 開始
- 対象範囲: Phase 1-3 完了 - 基本設定からフロントエンドまでの全体像
- 目的: ActionCableの基本構成と設計思想を理解する

## 2. 見つけた事実 / 理解したこと

### 基本設定
- **config/cable.yml**: Redis使用、チャンネルプリフィックス `chatwoot_{Rails.env}_action_cable`
- **routes.rb**: ActionCableの明示的なマウントなし（デフォルト `/cable` エンドポイント）
- **application_cable/connection.rb**: 空の実装（認証なし）
- **application_cable/channel.rb**: 空の実装（基本機能のみ）

### チャンネル実装 
- **RoomChannel**: 唯一の具体的チャンネル
  - pubsub_tokenベースの認証 (`room_channel.rb:42-47`)
  - User/Contact両方をサポート (`room_channel.rb:53-57`)
  - 在席状況管理（OnlineStatusTracker連携）
  - 2つのストリーム: `pubsub_token` と `account_{id}` (`room_channel.rb:28-29`)

### ブロードキャスト基盤
- **ActionCableListener**: イベント駆動でのブロードキャスト（Wisperパターン）
  - 40以上のイベントハンドラ（message_created, conversation_updated等）
  - pubsub_tokenベースのターゲット配信 (`action_cable_listener.rb:196-205`)
- **ActionCableBroadcastJob**: 非同期ブロードキャスト処理
  - Sidekiq使用、`critical`キュー
  - データ新鮮性の確保（最新データ再取得機能）

### フロントエンド実装
- **BaseActionCableConnector**: 共通基盤クラス
  - 自動再接続機能（1秒間隔チェック）
  - プレゼンス更新（20秒間隔）
  - WebSocket URL設定対応
- **ActionCableConnector**: Dashboard用具象クラス
  - 35+のイベントハンドラ
  - Vuexストアとの完全統合
  - 音声通知、タイピング表示等のUX機能

## 3. 仮説検証結果
| 仮説 | 結果 | 根拠 (ファイル/行/実験) | 次アクション |
|------|------|--------------------------|-------------|
| リアルタイムメッセージ送信に使用 | ✅ 正解 | ActionCableListener.message_created:33-38 | - |
| エージェント在席状況表示に使用 | ✅ 正解 | RoomChannel.broadcast_presence:19-24 | - |
| 通知機能で使用 | ✅ 正解 | ActionCableListener.notification_created:4-8 | - |
| 認証はDevise Token Auth連携 | ❌ 不正解 | connection.rb:1-2（空実装）、代わりにpubsub_token使用 | - |
| フロントエンドはVue.js実装 | ✅ 正解 | dashboard/helper/actionCable.js全体 | - |

## 4. 新たな疑問/派生トピック

### 設計上の興味深い点
- **なぜConnection層で認証しないのか？**: RoomChannelレベルでpubsub_tokenによる認証を実装
- **pubsub_tokenの生成タイミング**: User/ContactInboxモデルでの生成方法
- **スケーラビリティ**: Redis使用だが、複数サーバー構成での考慮事項
- **セキュリティ**: pubsub_tokenの漏洩リスクと対策

### 実装の工夫
- **データ新鮮性**: ActionCableBroadcastJobでの最新データ再取得
- **自動再接続**: フロントエンドでの堅牢な再接続ロジック
- **イベント駆動**: Wisperを使った疎結合なブロードキャスト

## 5. TODO/フォローアップ
- [x] 基本設定ファイルの確認完了
- [x] チャンネル実装の詳細確認
- [x] フロントエンド連携の確認
- [ ] pubsub_tokenの生成・管理方法の確認
- [ ] OnlineStatusTrackerの実装詳細
- [ ] テスト実装の確認（spec/channels/）
- [ ] パフォーマンス・スケーラビリティ考慮事項の調査