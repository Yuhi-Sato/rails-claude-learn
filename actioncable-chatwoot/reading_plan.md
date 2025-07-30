# 読解計画書 - ChatwootにおけるActionCableの実装

## 1. 対象コードベースの俯瞰
- **リポジトリ構成**: Rails 7.1 + Vue.js 3のフルスタックアプリケーション
- **ActionCable配置**: 
  - バックエンド: `app/channels/` (Channel定義), `app/channels/application_cable/` (基盤)
  - フロントエンド: `app/javascript/` (クライアント実装)
  - 設定: `config/cable.yml`, `config/routes.rb`
- **主要エントリポイント**: 
  - サーバー側: `application_cable/connection.rb` (認証・接続管理)
  - クライアント側: `app/javascript/shared/helpers/ActionCableConnector.js` (推定)
- **重要な依存関係**: Devise Token Auth (認証), Sidekiq (バックグラウンド処理), Vue.js (フロントエンド)

## 2. 読解ルートマップ
### 2.1 優先ルート（必ず読む）
1. **`config/cable.yml`** : ActionCableの基本設定 / 接続先・アダプター設定の確認
2. **`config/routes.rb`** : ActionCableのマウント確認 / ルーティング設定の理解
3. **`app/channels/application_cable/connection.rb`** : 認証・接続基盤 / Devise Token Auth連携仮説の検証
4. **`app/channels/application_cable/channel.rb`** : チャンネル基底クラス / 共通機能の確認
5. **`app/channels/` 配下の具体的チャンネル** : 実装パターン / メッセージ・通知・在席状況の各機能
6. **メッセージ関連コントローラー** : ActionCableとの連携ポイント / ブロードキャスト呼び出し箇所
7. **`app/javascript/` 内ActionCable関連** : クライアント実装 / Vue.jsとの統合方法

### 2.2 補助ルート（必要に応じて）
- **`spec/channels/`** : チャンネルのテスト実装 / テスト方法の学習
- **`app/jobs/` 内のActionCable関連ジョブ** : 非同期ブロードキャスト / バックグラウンド処理連携
- **WebSocket関連のミドルウェア** : パフォーマンス・セキュリティ対策
- **`config/environments/` のActionCable設定** : 環境別設定 / 本番運用の考慮事項

## 3. トレース方針
- **呼び出し追跡**: 
  - `grep -r "ActionCable\|broadcast" app/` でブロードキャスト箇所を特定
  - `grep -r "channel\|subscribe" app/javascript/` でクライアント側購読箇所を特定
  - GitHubのcode searchやIDEの参照機能を活用
- **動作確認**:
  - ブラウザのDevToolsでWebSocket接続とメッセージを監視
  - Rails consoleでのブロードキャストテスト
  - ActionCable::Server.broadcast直接実行による動作確認
- **ログ確認**:
  - `development.log`でActionCableのログを確認
  - WebSocketハンドシェイクのログ追跡

## 4. 実験計画
### 4.1 環境準備
- `pnpm dev` または `overmind start -f ./Procfile.dev` で開発環境起動
- Redis起動確認（ActionCableのアダプターとして使用）
- ブラウザで複数タブ開いてリアルタイム通信をテスト

### 4.2 小実験
1. **接続テスト**: ブラウザでWebSocket接続を確認
2. **メッセージ送信**: 実際にメッセージを送信してブロードキャストを観察
3. **在席状況**: エージェントのオンライン・オフライン切り替えを確認
4. **認証**: ログイン・ログアウト時のActionCable接続変化を観察
5. **Rails console実験**: 手動でのbroadcast送信テスト

## 5. 成果物テンプレート
### 5.1 読解ログ書式
```markdown
## [ファイル名] - [日付]
### 目的: 何を確認するために読んだか
### 発見:
- 重要な実装ポイント
- 予想との違い
- 他ファイルとの関連
### 疑問・TODO:
- 未解決の疑問
- 次に読むべきファイル
```

### 5.2 図・メモ形式
- **構成図**: mermaid.jsでチャンネル・コネクション関係図
- **フロー図**: メッセージ送信・受信の処理フロー
- **実装メモ**: 各チャンネルの役割・メソッド一覧表

## 6. タイムボックス & 優先度再確認
### 6.1 時間配分
- **Phase 1** (2-3時間): 基本構成・設定ファイル確認
- **Phase 2** (3-4時間): 主要チャンネル実装の読解
- **Phase 3** (2-3時間): フロントエンド連携部分
- **Phase 4** (1-2時間): テスト・エラーハンドリング
- **Phase 5** (1時間): まとめ・ドキュメント作成

### 6.2 切り上げ基準
- **Phase 1完了基準**: ActionCableの全体像と主要チャンネルを把握
- **最低限達成目標**: メッセージ送受信フローを図解できる状態
- **理想的ゴール**: 新しいチャンネルを作成できるレベルの理解

### 6.3 スコープ調整
- **コードが複雑すぎる場合**: 特定の一つの機能（例：メッセージ送信）に絞る
- **時間不足の場合**: Phase 4-5を省略し、Phase 1-3に集中
- **追加学習が必要な場合**: Devise Token Auth、Vue.jsの理解を先行

## 7. 成功指標
- [ ] ActionCableの基本構成を図解できる
- [ ] 主要なチャンネルの役割を説明できる
- [ ] メッセージ送受信フローを追跡できる
- [ ] 認証・認可の仕組みを理解している
- [ ] フロントエンドとの連携方法を把握している
- [ ] 実際に小さな修正・追加ができそうだと感じる