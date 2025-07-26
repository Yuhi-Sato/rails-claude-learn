# 読解計画書 - Action Cable

## 1. 対象コードベースの俯瞰

### リポジトリ/ディレクトリ構成の概要
```
actioncable/
├── lib/action_cable/          # コア実装
│   ├── connection/            # WebSocket接続管理
│   ├── channel/               # チャンネル（ビジネスロジック）
│   ├── subscription_adapter/  # Redis等のアダプター
│   └── engine.rb             # Rails統合
├── app/assets/javascripts/    # フロントエンド（Consumer）
├── test/                     # テストスイート
└── examples/                 # 実装例（もしあれば）
```

### 主要エントリポイント
- **サーバーサイド**: `ActionCable::Connection::Base` - WebSocket接続の管理
- **チャンネル**: `ActionCable::Channel::Base` - 業務ロジックとWebSocketの橋渡し
- **フロントエンド**: `ActionCable.Consumer` - JavaScriptクライアント
- **Rails統合**: `ActionCable::Engine` - Railsアプリケーションとの統合

### 重要モジュール・依存関係
- ActiveRecord（認証・データアクセス）
- Redis/PostgreSQL（Pub/Subアダプター）
- WebSocket-driver gem
- Concurrent-ruby（並行処理）

## 2. 読解ルートマップ

### 2.1 優先ルート（必ず読む）

#### Phase 1: 基本アーキテクチャ理解
1. **`actioncable/lib/action_cable.rb`** : エントリポイント、モジュール構成の把握
2. **`actioncable/lib/action_cable/connection/base.rb`** : Connection基底クラス、WebSocket接続管理の仕組み
3. **`actioncable/lib/action_cable/channel/base.rb`** : Channel基底クラス、購読・配信の仕組み
4. **`actioncable/app/assets/javascripts/action_cable.js`** : Consumer JavaScript API

#### Phase 2: 実装パターン理解  
5. **`actioncable/test/cases/connection_test.rb`** : 接続処理の具体例
6. **`actioncable/test/cases/channel_test.rb`** : チャンネル実装の具体例
7. **`actioncable/lib/action_cable/server/base.rb`** : サーバー統合部分

#### Phase 3: アダプターとスケーラビリティ
8. **`actioncable/lib/action_cable/subscription_adapter/redis.rb`** : Redisアダプター実装
9. **`actioncable/lib/action_cable/subscription_adapter/async.rb`** : 開発用アダプター
10. **`actioncable/lib/action_cable/subscription_adapter/postgresql.rb`** : PostgreSQLアダプター

### 2.2 補助ルート（必要に応じて）

#### 認証・認可関連
- **`actioncable/test/cases/connection/authorization_test.rb`** : 認証実装例の確認
- **`actioncable/lib/action_cable/connection/identification.rb`** : ユーザー識別の仕組み

#### パフォーマンス・最適化関連  
- **`actioncable/lib/action_cable/connection/stream.rb`** : ストリーミング最適化
- **`actioncable/lib/action_cable/remote_connections.rb`** : リモート接続管理

#### テスト関連
- **`actioncable/test/test_helper.rb`** : テスト環境のセットアップ
- **`actioncable/test/cases/channel/test_case_test.rb`** : テストケースの書き方

## 3. トレース方針

### 呼び出し追跡方法
```bash
# クラス・メソッド定義の検索
rg "class.*Connection" actioncable/lib/
rg "def.*subscribe" actioncable/lib/

# 使用箇所の追跡
rg "ActionCable::Connection" actioncable/
rg "identified_by" actioncable/test/

# JavaScript側の連携確認
rg "consumer.subscribe" actioncable/app/assets/
```

### ログ/デバッガ/テストで確認したいポイント
- WebSocket接続確立〜切断のライフサイクル
- チャンネル購読時のサーバー内部処理フロー
- Redis Pub/Sub経由でのメッセージ配信経路
- 認証失敗時の切断処理
- エラーハンドリングの動作

## 4. 実験計画

### 小実験リスト
1. **最小構成のAction Cableアプリ作成** : 基本的な接続・配信動作の確認
2. **認証機能付きチャット実装** : identified_by と認証フローの理解
3. **Redisアダプター切り替えテスト** : Async → Redis での動作比較
4. **負荷テスト小実験** : 複数接続時のメモリ・CPU使用状況確認

### 必要な準備
- Redis サーバーのローカル起動
- Rails testアプリケーションの準備
- ブラウザでのWebSocket Inspector使用準備

## 5. 成果物テンプレート

### 読解ログの書式
```markdown
## [ファイル名] 読解メモ

### 概要
- 役割: 
- 主要クラス/モジュール:

### 重要メソッド
- メソッド名: 処理内容の要約

### 仮説検証結果
- 検証した仮説:
- 結果: ✓/✗
- 根拠:

### 疑問・次に調べること
- 
```

### アーキテクチャ図テンプレート
- Connection ↔ Channel ↔ Consumer の関係図
- メッセージフローの図（サーバー→クライアント、クライアント→サーバー）
- アダプターを含むシステム構成図

### コード例テンプレート
- 最小限のConnection/Channel実装例
- フロントエンド接続・購読のJavaScriptコード例
- テストコード例

## 6. タイムボックス & 優先度再確認

### 各ルートの目安時間
- **Phase 1（基本理解）**: 4-6時間
  - Connection/Channel/Consumer の核心部分の理解
- **Phase 2（実装パターン）**: 3-4時間  
  - テストコードからの実装例理解
- **Phase 3（アダプター）**: 2-3時間
  - Redis等のスケーラビリティ対応理解

### 切り上げ基準・スコープ調整基準
- **最低限達成目標**: Connection、Channel、Consumerの関係を説明でき、シンプルなチャット機能を実装できる
- **理想的達成目標**: 認証機能付きで、Redisアダプター使用のスケーラブルなリアルタイム機能を実装できる
- **切り上げ判断**: Phase 1で6時間超過時はPhase 2を簡略化、Phase 3は概要理解のみ

### スコープ調整の優先度
1. 削らない: Connection、Channel、Consumer の基本理解
2. 簡略化可能: パフォーマンス最適化の詳細
3. 後回し可能: 複数アダプターでの動作比較、複雑なテストケース

## 7. チェックポイント
- [ ] Phase 1完了: Action Cableの三大要素の役割を図で説明できる
- [ ] Phase 2完了: シンプルなリアルタイム機能を実装できる  
- [ ] Phase 3完了: アダプターの切り替えとその影響を理解している
- [ ] 全体完了: 学習要件定義の完了基準をすべて満たしている