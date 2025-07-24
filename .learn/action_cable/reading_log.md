# 読解ログ - Action Cable

## 1. セッション概要
- 日付/時間: 2025-01-24 Phase 1実行
- 対象範囲: actioncable/lib/action_cable.rb, action_cable/connection/base.rb, action_cable/channel/base.rb, actioncable/app/assets/javascripts/action_cable.js
- 目的: Action Cableの基本アーキテクチャ（Connection、Channel、Consumer）の理解と仮説検証

## 2. 見つけた事実 / 理解したこと

### actioncable/lib/action_cable.rb
- ZeitwerkによるAutoloadingが設定されている（line 35-50）
- INTERNAL定数でWebSocketメッセージタイプが定義されている: welcome, disconnect, ping, confirmation, rejection（line 58-74）
- デフォルトマウントパスは"/cable"（line 72）
- Singletonパターンでサーバーインスタンスを管理：`ActionCable.server`（line 77-79）

### actioncable/lib/action_cable/connection/base.rb  
- **WebSocket接続の管理**: ConnectionクラスはWebSocket接続ごとにインスタンス化される（line 12-14）
- **認証・認可専用**: 具体的なアプリケーションロジックは含まず、認証・認可のみを扱う（line 15-17）
- **identified_by**: ユーザー識別の仕組み（line 23, line 42-46）
- **cookiesアクセス**: WebSocket接続確立時のcookiesが利用可能（line 187-189）
- **非同期処理**: worker_poolによる非同期メソッド実行（line 131-133）
- **メッセージ処理フロー**: receive → dispatch_websocket_message → handle_channel_command → subscriptions.execute_command（line 97-113）
- **接続ライフサイクル**: handle_open（connect実行、welcome送信）→ handle_close（disconnect実行）（line 199-220）

### actioncable/lib/action_cable/channel/base.rb
- **長寿命インスタンス**: Channelインスタンスは接続が続く限り存在し、メモリ管理に注意が必要（line 18-24）
- **RPC モデル**: RESTfulではなくremote-procedure callモデル（line 51-55）
- **自動Action公開**: パブリックメソッドは自動的にクライアントから呼び出し可能（action_methods, line 128-138）
- **パラメータフィルタリング**: parameter_filterでログ出力をサニタイズ（line 309-311）
- **Connection識別子の委譲**: connectionのidentifiersが自動的にchannelでアクセス可能（line 270-276）
- **Subscription管理**: subscribed/unsubscribed コールバック、rejectによる購読拒否（line 191-198, line 262-268）

### actioncable/app/assets/javascripts/action_cable.js
- **Consumer**: フロントエンドでWebSocket接続とSubscriptionを管理（line 442-471）
- **ConnectionMonitor**: 接続監視、自動再接続、stale detection（line 20-111）
- **Subscription**: チャンネルとの通信、perform()でサーバーアクション呼び出し（line 310-330）
- **SubscriptionGuarantor**: 購読の確実性を保証、再購読機能（line 331-366）
- **メッセージタイプ処理**: welcome（再接続リセット）、confirmation（購読確認）、rejection（購読拒否）、ping（接続確認）、disconnect（切断）（line 240-274）

## 3. 仮説検証結果

| 仮説 | 結果 | 根拠 (ファイル/行/実験) | 次アクション |
|------|------|--------------------------|--------------|
| ConnectionクラスがWebSocket接続を管理している | ✓完全に正しい | connection/base.rb:12-14「WebSocket connection毎にConnection objectが作られる」 | Phase 2でテストコードを確認 |
| ChannelクラスがビジネスロジックとWebSocketを橋渡ししている | ✓完全に正しい | channel/base.rb:12-16「controller-likeだがpush機能も持つ」 | 実装例を確認 |
| フロントエンドのConsumerが接続を管理している | ✓完全に正しい | action_cable.js:442-471 ConsumerクラスがConnection/Subscriptionsを管理 | 実際の使用例を確認 |

## 4. 新たな疑問/派生トピック

- **MessageBuffer**: Connection::MessageBuffer の役割と実装（connection/base.rb:75で発見）
- **SubscriptionAdapter**: 具体的なPub/Sub実装の詳細
- **Streams**: Channel::Streamsモジュールの詳細実装 
- **テスト方法**: Channel/ConnectionのテストはどのようにTestCaseで書くのか
- **パフォーマンス**: 長寿命Channelインスタンスのメモリリーク対策
- **認証実装例**: 実際のidentified_byとcookiesを使った認証パターン

## 5. TODO/フォローアップ

- [ ] Phase 2: テストコードから実装パターンを学習
- [ ] MessageBufferクラスの実装確認
- [ ] Streamsモジュールの実装確認  
- [ ] 認証実装例の確認（test/cases/connection/authorization_test.rb）
- [ ] Redisアダプター実装の確認
- [ ] 最小限のサンプル実装作成

## 6. アーキテクチャ理解

### 全体構成
```
[Browser] Consumer (JS)
    ↓ WebSocket
[Rails] Connection (認証・接続管理)
    ↓ command routing
[Rails] Channel (ビジネスロジック)
    ↓ pub/sub
[Redis/PG] SubscriptionAdapter (スケーラビリティ)
```

### メッセージフロー
1. **接続確立**: Consumer.connect() → Connection.process() → handle_open() → connect() → welcome送信
2. **購読**: Consumer.subscriptions.create() → Connection.handle_channel_command() → Channel.subscribe_to_channel()
3. **メッセージ送信**: Subscription.perform() → Connection.receive() → Channel.perform_action()
4. **切断**: Consumer.disconnect() → Connection.close() → handle_close() → disconnect()

## 7. Phase 1 完了確認

✅ Action CableのConnection、Channel、Consumerの役割を理解
✅ WebSocket接続管理の仕組みを理解  
✅ メッセージフローの全体像を把握
✅ 認証・認可の基本概念を理解
✅ JavaScriptクライアントAPIの使い方を理解

**次のステップ**: Phase 2でテストコードから具体的な実装パターンを学習

---

## セッション2: Streamsモジュール深掘り
- 日付/時間: 2025-01-24 Streams深掘り
- 対象範囲: actioncable/lib/action_cable/channel/streams.rb, broadcasting.rb, test/channel/stream_test.rb
- 目的: Streamsモジュールの詳細実装とリアルタイムデータ配信の仕組みを理解

### 見つけた事実 / 理解したこと

#### actioncable/lib/action_cable/channel/streams.rb
- **純粋なオンラインキュー**: broadcastingは純粋にオンラインのpubsubキュー、リアルタイムでのみ配信（line 9-14）
- **stream_from(broadcasting, callback, coder)**: 指定したbroadcastingからストリーミング開始、オプションでコールバック・エンコーダー指定可能（line 90-109）
- **defer_subscription_confirmation!**: pubsub#subscribeが成功するまで確認を遅延（line 95-96）
- **worker_pool非同期実行**: user_handlerはworker_poolで非同期実行、event loopをブロックしない（line 163-169）
- **stream_for(model)**: モデルから自動的にbroadcasting名を生成してストリーミング（line 118-120）
- **コーデック対応**: JSON以外のカスタムエンコーダーも使用可能（line 175-202）
- **自動購読解除**: on_unsubscribe :stop_all_streams で自動的に全ストリーム停止（line 81-82）

#### actioncable/lib/action_cable/channel/broadcasting.rb  
- **GlobalID対応**: モデルオブジェクトを to_gid_param でシリアライズ（line 33-34）
- **broadcasting_for生成ルール**: [channel_name, model] → "comments:Z2lkOi8v..." 形式（line 24-26）
- **broadcast_to**: クラスメソッドでモデル向けにブロードキャスト送信（line 14-16）

#### test/channel/stream_test.rb
- **EventMachine前提**: run_in_eventmachine でテスト実行（line 57）
- **Mock使用**: Minitest::Mock でpubsubをモック化してテスト（line 59-62）
- **非同期確認**: wait_for_async で非同期処理完了を待機（line 68）
- **並行処理テスト**: CyclicBarrierを使った同時実行テスト（line 284-339）
- **カスタムエンコーダー**: DummyEncoderでエンコード/デコードをテスト（line 43-47）
- **確認送信制御**: subscription_confirmationは一度だけ送信される（line 165-180）

### Streamsの核心メカニズム理解

#### 1. ストリーミング開始フロー
```ruby
stream_from "channel_name" do |message|
  # カスタム処理
  transmit message
end
```
1. defer_subscription_confirmation! で確認を遅延
2. worker_pool_stream_handler でハンドラーをラップ
3. connection.server.event_loop.post で非同期実行
4. pubsub.subscribe でPub/Sub購読開始
5. 成功時に ensure_confirmation_sent で確認送信

#### 2. メッセージ配信フロー
```ruby
ActionCable.server.broadcast "channel_name", { data: "value" }
```
1. サーバーがbroadcastingにメッセージ送信
2. pubsubアダプターが購読者に配信
3. stream_handlerがメッセージを受信
4. worker_poolで非同期にuser_handler実行
5. デフォルトではJSONデコード→transmit

#### 3. 購読管理
- **streams**: @_streams ||= {} でチャンネル毎に管理（line 157-159）
- **stop_all_streams**: 全broadcastingから購読解除（line 137-142）
- **自動解除**: unsubscribeコールバックで自動的にstop_all_streams実行

#### 4. パフォーマンス考慮
- **Event Loop保護**: user_handlerは必ずworker_poolで実行
- **非同期購読**: event_loop.postで購読処理を非同期化
- **メモリ効率**: streamsハッシュで購読状態を軽量管理

### 新たな疑問/派生トピック

- **PubSubアダプター**: Redis/PostgreSQL/Asyncの実装差異
- **Global ID**: to_gid_paramの詳細とActive Recordとの連携
- **Event Loop**: connection.server.event_loopの実装詳細
- **Worker Pool**: 非同期実行の並行数制御とメモリ管理
- **カスタムコーダー**: 実用的なカスタムエンコーダーの実装例
- **ブロードキャスト効率**: 大量配信時のパフォーマンス最適化

### TODO/フォローアップ追加

- [ ] Redis/Async/PostgreSQLアダプターの実装比較
- [ ] Event Loopの実装確認（Concurrent Ruby使用？）
- [ ] Worker Poolの設定とスケーリング
- [ ] 大量ブロードキャスト時のメモリ使用量測定
- [ ] GlobalIDとActive Recordモデルの連携確認

---

## セッション3: Connection::Baseのserver引数と初期化フロー
- 日付/時間: 2025-01-24 server引数調査
- 対象範囲: actioncable/lib/action_cable/server/base.rb, engine.rb
- 目的: Connection::Baseのserver引数の正体とinitialize実行箇所を理解

### 見つけた事実 / 理解したこと

#### server引数の正体
**server引数 = ActionCable::Server::Baseインスタンス**

#### actioncable/lib/action_cable/server/base.rb
- **Singletonパターン**: ActionCable.server でシングルトンインスタンスを取得（action_cable.rb:77-79）
- **Rackアプリケーション**: Server::Base#call(env) でHTTPリクエストを処理（line 38-42）
- **Connection作成**: `config.connection_class.call.new(self, env).process` で0Connectionインスタンス作成（line 41）
- **資源管理**: event_loop, worker_pool, pubsub を避刊初期化で管理（line 71-98）
- **Worker Pool**: デフォルト最大4スレッド、コネクションプールサイズとの関係に注意（line 75-93）

#### actioncable/lib/action_cable/engine.rb
- **Rails統合**: Rails::Engine で自動的に Action Cable を統合（line 10）
- **デフォルトマウント**: "/cable" パスに自動マウント（line 12, 67）
- **ApplicationCable::Connection**: デフォルトのConnectionクラスを設定（line 55）
- **Executorラップ**: RailsのexecutorでChannelのcallbackをラップ（line 75-91）

### Connection::Base初期化フローの全体像

#### 1. Railsアプリケーション起動時
```ruby
# 1. Railsエンジン初期化
ActionCable::Engine.initializer "action_cable.routes" do
  app.routes.prepend do
    mount ActionCable.server => "/cable"  # デフォルト
  end
end

# 2. シングルトンサーバーインスタンス作成
ActionCable.server  # => ActionCable::Server::Base.new
```

#### 2. WebSocketリクエスト受信時
```ruby
# 1. RackリクエストがActionCable.serverに届く
GET /cable HTTP/1.1
Connection: Upgrade
Upgrade: websocket

# 2. Server::Base#call(env) が呼び出される
def call(env)
  config.connection_class.call.new(self, env).process
  #                             ^^^^  ^^^^ 
  #                             |     └─ Rack環境
  #                             └────── Server::Baseインスタンス
end

# 3. Connection::Base.new(server, env) が実行される
def initialize(server, env, coder: ActiveSupport::JSON)
  @server = server  # ActionCable::Server::Baseインスタンス
  @env = env        # Rack環境ハッシュ
end
```

#### 3. Connectionがサーバーリソースにアクセスする仕組み
```ruby
# Connection::Baseではserverを通じて共有リソースにアクセス
class ActionCable::Connection::Base
  delegate :event_loop, :pubsub, :config, to: :server
  
  def initialize(server, env, coder: ActiveSupport::JSON)
    @worker_pool = server.worker_pool      # スレッププール
    # server.event_loop                    # イベントループ
    # server.pubsub                        # Pub/Subアダプター
    # server.config                        # 設定
  end
end
```

### 新たな疑問/派生トピック

- **connection_class.call**: なぜ call() メソッドが必要なのか？
- **config.connection_class**: デフォルトでApplicationCable::Connectionになる仕組み
- **Lazy初期化**: event_loop, worker_pool, pubsubが避刊初期化される理由
- **Monitor使用**: なぜMutexではなくMonitorを使用するのか
- **Worker Poolサイジング**: データベースコネクションプールとの関係

## 理解のポイント

1. **server引数** = ActionCable::Server::Baseのシングルトンインスタンス
2. **初期化タイミング** = WebSocketリクエスト受信時にServer::Base#call(env)で実行
3. **リソース共有** = Connectionは server を通じて共有リソース（worker_pool, event_loop, pubsub）にアクセス
4. **Rails統合** = ActionCable::Engineで自動的にマウント、ApplicationCable::Connection設定

---

## セッション4: Worker Poolの詳細実装
- 日付/時間: 2025-01-24 Worker Pool調査
- 対象範囲: actioncable/lib/action_cable/server/worker.rb, active_record_connection_management.rb, configuration.rb
- 目的: Worker Poolの実装とデータベース接続管理、非同期処理の仕組みを理解

### 見つけた事実 / 理解したこと

#### actioncable/lib/action_cable/server/worker.rb
- **Concurrent::ThreadPoolExecutor使用**: 名前付きスレッププール "ActionCable-server"（line 22-28）
- **デフォルト設定**: min_threads:1, max_threads:5 (configで変更可), max_queue:0（キューなし）
- **thread_mattr_accessor :connection**: スレッドローカルで現在のConnectionを管理（line 15）
- **ActiveSupport::Callbacks**: :work コールバックでActiveRecord統合（line 16, 43）
- **async_invoke vs async_exec**: invokeはmethod呼び出し、execはinstance_exec実行（line 48-56）
- **例外処理**: ワーカー内での例外をキャッチしてログ出力（line 61-66）

#### actioncable/lib/action_cable/server/worker/active_record_connection_management.rb
- **条件付き統合**: ActiveRecord::Baseが定義されている場合のみ有効（line 12-14）
- **ログ統合**: ActionCableのconnection.loggerとActiveRecordのloggerを統合（line 17-19）
- **軽量実装**: 複雑なコネクションプール管理はしない、ログのタグ付けのみ

#### actioncable/lib/action_cable/server/configuration.rb
- **worker_pool_size**: デフォルト4スレッド（line 26）
- **pubsub_adapter**: デフォルトRedis、動的ロードとエラーハンドリング（line 40-67）

### Worker Poolの使用パターン

#### 1. ストリーミングメッセージ処理
```ruby
# streams.rb:167
def worker_pool_stream_handler(broadcasting, user_handler, coder: nil)
  -> message do
    connection.worker_pool.async_invoke handler, :call, message, connection: connection
  end
end
```
**目的**: メッセージ受信時のユーザーハンドラーを非同期実行、Event Loopをブロックしない

#### 2. WebSocketライフサイクル処理
```ruby
# connection/base.rb:98, 152, 165
def receive(websocket_message)
  send_async :dispatch_websocket_message, websocket_message
end

def on_open
  send_async :handle_open
end

def on_close(reason, code)
  send_async :handle_close
end
```
**目的**: WebSocketイベントの重い処理を非同期化、接続の応答性を維持

#### 3. 定期タイマー
```ruby
# channel/periodic_timers.rb:68
def start_periodic_timer(callback, every:)
  connection.server.event_loop.timer every do
    connection.worker_pool.async_exec self, connection: connection, &callback
  end
end
```
**目的**: チャンネルの定期処理（heartbeat等）をワーカープールで実行

### アーキテクチャ統合パターン

#### 処理の分離
```
【Event Loopスレッド】          【Worker Poolスレッド群】
- WebSocket I/O               - メッセージ処理
- コネクション管理             - ユーザーコード実行
- タイマー管理                - データベースアクセス
- イベントディスパッチ       - Channelコールバック
                                  - 定期タイマー処理
```

#### パフォーマンス考慮点

**1. スレッドプールサイジング**
- デフォルト: max_threads=4 (設定で変更可)
- max_queue=0: キューなし、スレッドがすべて使用中の場合はブロック

**2. データベース接続計算**
```
5サーバー × 5Pumaワーカー × 8ワーカープール = 200DB接続
```

**3. メモリ管理**
- thread_mattr_accessorでスレッドローカル変数管理
- workメソッドでensureでconnection=nil設定、メモリリーク防止

### 新たな疑問/派生トピック

- **max_queue=0の意味**: キューなしでブロックする設計の理由
- **Concurrent Ruby**: ThreadPoolExecutorの内部実装とパフォーマンス
- **ActiveRecord統合**: ログ以外のコネクション管理はあるのか
- **スケーリング戦略**: 大量同時接続時のワーカープール調整
- **メトリクス**: ワーカープールの使用状況監視方法

### TODO/フォローアップ追加

- [ ] Concurrent::ThreadPoolExecutorの詳細仕様確認
- [ ] max_queue=0のパフォーマンス影響測定
- [ ] 大量接続時のワーカープールサイジング戦略
- [ ] ActiveRecord以外のデータストア（Redis等）との統合
- [ ] ワーカープールのメトリクス収集方法

---

## セッション5: Redis Pub/SubアダプターとMessageBufferの詳細実装
- 日付/時間: 2025-01-24 Redis & MessageBuffer調査
- 対象範囲: actioncable/lib/action_cable/subscription_adapter/redis.rb, connection/message_buffer.rb, subscription_adapter/base.rb, subscriber_map.rb
- 目的: スケーラブルPub/Sub実装とWebSocketメッセージバッファリングの仕組みを理解

### 見つけた事実 / 理解したこと

#### actioncable/lib/action_cable/subscription_adapter/redis.rb

##### Redisアダプターの核心設計
- **接続分離**: broadcast用とsubscription用で別々のRedis接続を使用（line 25, 44-46）
- **redis_connector**: カスタマイズ可能なRedisコネクター（Makaraプロキシ対応）（line 18-20）
- **ChannelPrefix**: prependでチャンネル名のプレフィックス機能（line 13）
- **Mutexでスレッドセーフティ**: @server.mutex.synchronizeで接続初期化を保護（line 50, 54）

##### Listenerクラスの複雑な実装
- **再接続管理**: @reconnect_attempts配列で段階的なsleep時間を設定（line 79-80）
- **内部チャンネル**: "_action_cable_internal"で接続状態を管理（line 93）
- **when_connectedキュー**: 接続完了後に実行するコールバックをキューイング（line 84, 100-102）  
- **スレッド安全性**: @subscription_lock Mutexで購読状態を保護（line 75）
- **Redisバージョン対応**: v4/v5で異なるSubscribedClient実装（line 212-257）

##### ライフサイクル管理
```ruby
# 接続確立フロー
conn.subscribe("_action_cable_internal") do |on|
  on.subscribe do |chan, count|
    if count == 1  # 初回接続
      @reconnect_attempt = 0
      @subscribed_client = original_client
      # when_connectedキューを全て実行
    end
  end
end
```

#### actioncable/lib/action_cable/connection/message_buffer.rb

##### シンプルだが重要な設計
- **初期化前のメッセージバッファリング**: WebSocket接続確立Immediately後、Connection初期化完了までのメッセージを保存（line 7-8）
- **文字列験証**: 非Stringメッセージをエラーログ出力で拒否（line 40-42）
- **状態管理**: @processingフラグでバッファリング/直接処理を切り替え（line 17-21）
- **FIFO処理**: バッファーされたメッセージを順序通りにshiftで処理（line 52-54）

##### Connection初期化との連携
```ruby
# connection/base.rb:205 handle_openメソッド内
def handle_open
  # ... 接続処理 ...
  message_buffer.process!  # バッファー処理開始
end

# メッセージ受信時
def on_message(message)
  message_buffer.append message  # バッファーまたは直接処理
end
```

#### actioncable/lib/action_cable/subscription_adapter/subscriber_map.rb

##### スレッドセーフな購読者管理
- **Hash.new { |h, k| h[k] = [] }**: チャンネル別の購読者リスト管理（line 9）
- **Mutex同期**: @sync.synchronizeで全ての操作を保護（line 14, 28, 39）
- **参照数カウント**: 最後の購読者が削除されたらチャンネルをクリーンアップ（line 31-35）
- **コールバック実行**: broadcast時にduplicateしたリストで各subscriberに順次実行（line 39-46）

### Redis Pub/Subの全体アーキテクチャ

#### 1. ブロードキャストフロー
```ruby
# サーバーAでメッセージ送信
ActionCable.server.broadcast "chat_room_1", { message: "Hello" }
  ↓
Redis PUBLISH chat_room_1 '{"message":"Hello"}'
  ↓
Redisが全ての接続したサーバーにPUSH
  ↓
サーバーB, C, DのListener.broadcast()が呼び出される
  ↓
SubscriberMapがローカルの購読者にメッセージ送信
```

#### 2. 接続管理の考慮点
- **接続分離**: publish用とsubscribe用で別接続、パフォーマンス向上
- **再接続戦略**: 段階的なbackoffでRedis間欇的障害に対応
- **スレッド安全**: 複数Mutexでsubscription状態とコールバック管理を保護

#### 3. MessageBufferの役割
- **タイミング問題解決**: WebSocket接続確立とConnection初期化のギャップをバッファリングで解決
- **メッセージ順序保証**: FIFOで受信順序を維持
- **メモリ効率**: シンプルな配列で軽量バッファリング

### パフォーマンスとスケーラビリティ

#### Redis設定のベストプラクティス
```ruby
# 基本設定
{ adapter: "redis", url: "redis://localhost:6379/0" }

# 高可用性設定 (Redis Sentinel)
{ 
  adapter: "redis", 
  sentinels: [{ host: "sentinel1", port: 26379 }],
  url: "redis://mymaster"
}

# カスタムコネクター (Makara等)
ActionCable::SubscriptionAdapter::Redis.redis_connector = ->(config) {
  Makara::Redis.new(config)
}
```

#### スケーリング考慮点
- **接続プール**: Redis接続はActionCableサーバー数 × 2(最低限)
- **チャンネルプレフィックス**: 複数アプリケーション間の名前空間分離
- **メモリ使用量**: サブスクライブ数とメッセージサイズに比例

### 新たな疑問/派生トピック

- **Pub/Sub vs Streams**: Redis Streamsとの比較、永続化メッセージの必要性
- **バックプレッシャー**: Redis間歇時のActionCableサーバーの振る舞い
- **メトリクス**: Redisコネクション数、メッセージレートの監視
- **メモリリーク**: 長時間接続でのサブスクライブ情報の管理
- **レイテンシ**: RedisからActionCableサーバー、サーバーからクライアントまでの遊延測定

### TODO/フォローアップ追加

- [ ] Redis StreamsとPub/Subのパフォーマンス比較
- [ ] Redlockなどの分散ロックとの統合
- [ ] Redisクラスターモードでの動作検証
- [ ] 大量メッセージ時のMessageBufferのメモリ使用量
- [ ] 接続障害時のメッセージロスト率測定

---

## セッション6: Phase 2 - テストコードから学ぶ実装パターン
- 日付/時間: 2025-01-24 実装パターン学習
- 対象範囲: test/channel/test_case_test.rb, test/connection/authorization_test.rb, test/connection/identifier_test.rb, test/stubs/
- 目的: テストコードからAction Cableの実用的な実装パターンを理解

### 見つけた事実 / 理解したこと

#### INTERNAL定数の実用パターン
```ruby
INTERNAL = {
  message_types: {
    welcome: "welcome",           # 接続成功時のメッセージ
    disconnect: "disconnect",     # 切断時のメッセージ  
    ping: "ping",                 # ハートビート
    confirmation: "confirm_subscription", # 購読確認
    rejection: "reject_subscription"       # 購読拒否
  },
  disconnect_reasons: {
    unauthorized: "unauthorized",       # 認証失敗  
    invalid_request: "invalid_request", # 無効リクエスト
    server_restart: "server_restart",   # サーバー再起動
    remote: "remote"                    # リモート切断
  },
  protocols: ["actioncable-v1-json", "actioncable-unsupported"]
}
```

#### test/connection/authorization_test.rb
##### 認証・セキュリティパターン
```ruby 
class Connection < ActionCable::Connection::Base
  def connect
    reject_unauthorized_connection  # 認証失敗時の拒否
  end
end
```
- **未認証接続の処理**: `reject_unauthorized_connection`で自動的に切断
- **切断メッセージ**: `{type: "disconnect", reason: "unauthorized", reconnect: false}`を送信
- **WebSocketクローズ**: メッセージ送信後にwebsocket.close()実行

#### test/connection/identifier_test.rb
##### ユーザー識別パターン
```ruby
class Connection < ActionCable::Connection::Base
  identified_by :current_user  # 識別子宣言
  
  def connect
    self.current_user = User.new "lifo"  # ユーザー情報設定
  end
end
```
- **identified_by**: ユーザー識別子を宣言、自動的にattr_accessor作成
- **connection_identifier**: "User#lifo"形式で一意識別子生成
- **内部チャンネル**: "action_cable/User#lifo"で自動購読
- **リモート切断**: `process_internal_message`で"disconnect"メッセージ処理

#### test/channel/test_case_test.rb
##### Channelテストの実装パターン

**基本的なテスト構造**:
```ruby
class PerformTestChannelTest < ActionCable::Channel::TestCase
  def setup
    stub_connection user_id: 2016  # 接続スタブ作成
    subscribe id: 5                 # チャンネル購読
  end

  def test_perform_with_params
    perform :echo, text: "You are man!"  # アクション実行
    assert_equal({ "text" => "You are man!" }, transmissions.last)
  end
end
```

**ストリーミングテストパターン**:
```ruby
class StreamsTestChannel < ActionCable::Channel::Base
  def subscribed
    stream_from "test_#{params[:id] || 0}"  # パラメーターベースのストリーム
  end
  
  def unsubscribed
    stop_stream_from "test_#{params[:id] || 0}"  # ストリーム停止
  end
end

# テストでの検証
def test_stream_with_params
  subscribe id: 42
  assert_has_stream "test_42"       # ストリーム存在確認
  
  unsubscribe  
  assert_has_no_stream "test_42"    # ストリーム削除確認
end
```

**オブジェクトベースストリーム**:
```ruby
class StreamsForTestChannel < ActionCable::Channel::Base
  def subscribed
    stream_for User.new(params[:id])  # モデルオブジェクトベース
  end
end

# テスト検証
def test_stream_with_params
  subscribe id: 42
  assert_has_stream_for User.new(42)  # オブジェクトベース検証
end
```

**購読拒否パターン**:
```ruby
class RejectionTestChannel < ActionCable::Channel::Base
  def subscribed
    reject  # 購読拒否
  end
end

# 拒否状態の確認
def test_rejection
  subscribe
  
  assert_not subscription.confirmed?     # 確認されていない
  assert_predicate subscription, :rejected?  # 拒否されている
end
```

#### test/stubs/test_connection.rb
##### テスト用Connectionスタブ
```ruby
class TestConnection
  def initialize(user = User.new("lifo"), coder: ActiveSupport::JSON)
    @identifiers = [ :current_user ]  # 識別子リスト
    @current_user = user              # デフォルトユーザー
    @transmissions = []               # 送信メッセージ記録
  end
  
  def transmit(cable_message)
    @transmissions << encode(cable_message)  # メッセージをエンコードして記録
  end
end
```

### 実用的な実装パターン集

#### 1. 認証パターン
```ruby
# 基本認証
class ApplicationCable::Connection < ActionCable::Connection::Base
  identified_by :current_user
  
  def connect
    self.current_user = find_verified_user
  end
  
  private
    def find_verified_user
      verified_user = User.find_by(id: cookies.encrypted[:user_id])
      return verified_user if verified_user
      reject_unauthorized_connection
    end
end

# 複数識別子
class ApplicationCable::Connection < ActionCable::Connection::Base
  identified_by :current_user, :current_room
  
  def connect
    self.current_user = find_verified_user
    self.current_room = find_verified_room
  end
end
```

#### 2. Channel実装パターン
```ruby
# チャットチャンネル
class ChatChannel < ApplicationCable::Channel
  def subscribed
    @room = Room.find(params[:room_id])
    stream_from "chat_room_#{@room.id}"
  end
  
  def speak(data)
    # メッセージ送信処理
    message = @room.messages.create!(
      content: data['message'],
      user: current_user
    )
    
    # ブロードキャスト
    ChatChannel.broadcast_to(@room, {
      message: message.content,
      user: current_user.name,
      timestamp: message.created_at
    })
  end
  
  def unsubscribed
    stop_all_streams
  end
end

# 通知チャンネル
class NotificationChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user  # ユーザー固有の通知
  end
end

# 条件付き購読
class PrivateChannel < ApplicationCable::Channel
  def subscribed
    room = Room.find(params[:room_id])
    
    if room.accessible_by?(current_user)
      stream_for room
    else
      reject  # アクセス権なしで拒否
    end
  end
end
```

#### 3. テスト実装パターン
```ruby
# 統合テスト
class ChatChannelTest < ActionCable::Channel::TestCase
  def setup
    @user = users(:john)
    @room = rooms(:general)
    stub_connection current_user: @user
    subscribe room_id: @room.id
  end
  
  def test_speak_broadcasts_message
    assert_broadcast_on("chat_room_#{@room.id}", {
      message: "Hello World",
      user: @user.name
    }) do
      perform :speak, message: "Hello World"
    end
  end
  
  def test_subscription_confirmation
    assert subscription.confirmed?
    assert_has_stream "chat_room_#{@room.id}"
  end
end

# Connectionテスト
class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  def test_connects_with_valid_user
    user = users(:john)
    cookies.encrypted[:user_id] = user.id
    
    connect
    
    assert_equal user, connection.current_user
  end
  
  def test_rejects_invalid_user
    assert_reject_connection { connect }
  end
end
```

### 新たな疑問/派生トピック

- **コールバックタイミング**: after_subscribe, after_unsubscribeの実用性
- **エラーハンドリング**: Channel内での例外処理パターン
- **パフォーマンス**: 大量ユーザー時のメモリ使用量最適化
- **セキュリティ**: CSRF以外のセキュリティ考慮点
- **モニタリング**: 接続数、メッセージ数の監視方法

### TODO/フォローアップ追加

- [ ] 実際のRailsアプリケーションでの実装例作成
- [ ] パフォーマンステストとベンチマーク
- [ ] セキュリティベストプラクティス集
- [ ] エラーハンドリングとログ出力戦略
- [ ] スケーリング戦略とパフォーマンスチューニング

---

## セッション7: Singletonパターンの実現方法と実用的意味
- 日付/時間: 2025-01-24 Singleton調査
- 対象範囲: actioncable/lib/action_cable.rb, engine.rb, server/broadcasting.rb, test_helper.rb
- 目的: ActionCable.serverのSingletonパターンの実現方法とその実用的意味を理解

### 見つけた事実 / 理解したこと

#### Singletonパターンの実装

##### actioncable/lib/action_cable.rb:77-79
```ruby
# Singleton instance of the server
module_function def server
  @server ||= ActionCable::Server::Base.new
end
```

**実装のポイント**:
- **module_function**: ActionCableモジュールレベルで呼び出し可能APIを作成
- **@server ||=**: memoizationパターンで初回のみインスタンス作成
- **ActionCable::Server::Base.new**: 具体的なサーバーインスタンス作成

#### 実用的な使用例

##### 1. Rails統合 (engine.rb:67, 93)
```ruby
# ルーティング統合
mount ActionCable.server => "/cable", internal: true

# アプリケーション再起動時のクリーンアップ
app.reloader.before_class_unload do
  ActionCable.server.restart
end
```
**意味**: Railsアプリケーションのライフサイクルと統合、単一エントリーポイント

##### 2. ブロードキャスト機能 (broadcasting.rb:15, 21)
```ruby
# チャンネルレベル
def broadcast_to(model, message)
  ActionCable.server.broadcast(broadcasting_for(model), message)
end

# サーバーレベルでの直接ブロードキャスト
ActionCable.server.broadcast "chat_room_1", { message: "Hello" }
```
**意味**: アプリケーションのどこからでも统一されたブロードキャストAPIでアクセス

##### 3. テスト環境でのアダプター差し替え (test_helper.rb:9-15)
```ruby
def before_setup
  server = ActionCable.server
  test_adapter = ActionCable::SubscriptionAdapter::Test.new(server)
  @old_pubsub_adapter = server.pubsub
  server.instance_variable_set(:@pubsub, test_adapter)
end
```
**意味**: テスト時にシングルトンの状態を変更してモック化

##### 4. リモート接続管理 (remote_connections.rb:21, 30)
```ruby
# 特定ユーザーの全接続を切断
ActionCable.server.remote_connections.where(current_user: user).disconnect

# 再接続禁止で切断
ActionCable.server.remote_connections.where(current_user: user).disconnect(reconnect: false)
```
**意剣**: 分散環境でのユーザー接続管理を统一APIで実現

##### 5. 設定情報へのアクセス (action_cable_helper.rb:38-40)
```ruby
def action_cable_meta_tag
  tag "meta", name: "action-cable-url", content: (
    ActionCable.server.config.url ||
    ActionCable.server.config.mount_path ||
    raise("No Action Cable URL configured")
  )
end
```
**意味**: ビューヘルパーからサーバー設定にアクセス

##### 6. ストリーミング内部処理 (streams.rb:103)
```ruby
connection.server.event_loop.post do
  pubsub.subscribe(broadcasting, handler, lambda do
    ensure_confirmation_sent
  end)
end
```
**意味**: Connectionからサーバーの共有リソース(event_loop)にアクセス

### Singletonパターンが必要な理由

#### 1. **統一されたサーバーインスタンス管理**
```
アプリケーション全体
│
├─ Rails Controller  → ActionCable.server.broadcast()
├─ Background Job    → ActionCable.server.broadcast()
├─ Channel           → connection.server (same instance)
├─ View Helper       → ActionCable.server.config
└─ Test              → ActionCable.server (アダプター差し替え)

↓ 全て同一インスタンス

ActionCable::Server::Base インスタンス1個
├─ @config: 設定情報
├─ @pubsub: Pub/Subアダプター
├─ @worker_pool: ワーカースレッドプール
└─ @event_loop: イベントループ
```

#### 2. **状態と設定の一貫性**
- **設定情報**: アプリケーション全体で同一の設定を共有
- **リソース管理**: worker_pool, event_loop, pubsubを统一管理
- **接続管理**: 全WebSocket接続を単一インスタンスで追跡

#### 3. **Rails統合の簡素化**
- **マウントポイント**: Railsルーターに単一エントリーポイントとしてマウント
- **ライフサイクル管理**: アプリケーション再起動時のクリーンアップ

#### 4. **テストの容易さ**
```ruby
# テスト時にアダプターを簡単に差し替え
server = ActionCable.server
server.instance_variable_set(:@pubsub, test_adapter)

# シングルトンでなければ、すべてのコンポーネントで個別に差し替えが必要
```

#### 5. **APIの統一性**
```ruby
# どこからでも同一APIでアクセス
ActionCable.server.broadcast(channel, message)      # コントローラーから
ActionCable.server.remote_connections.disconnect    # 管理コマンドから
ActionCable.server.config.worker_pool_size         # 設定参照
```

### シングルトンなしでの問題点

もしシングルトンでなかった場合の問題:
```ruby
# シングルトンなしの場合(問題あり)
server1 = ActionCable::Server::Base.new  # コントローラー用
server2 = ActionCable::Server::Base.new  # チャンネル用
server3 = ActionCable::Server::Base.new  # ビュー用

# 問題点:
# 1. 設定の不一致: server1.config ≠ server2.config
# 2. リソースの重複: 複数のworker_pool, event_loop
# 3. 接続の分散: 異なるサーバーでWebSocket管理
# 4. テストの複雑化: すべてのインスタンスをモック化が必要
```

### 新たな疑問/派生トピック

- **マルチサーバー環境**: 複数Railsアプリケーションインスタンス間での状態共有
- **スレッド安全性**: シングルトンインスタンスへの同時アクセス
- **メモリリーク**: アプリケーションライフサイクルとシングルトンの関係
- **設定更新**: ランタイムでの設定変更の影響範囲
- **テスト絶縁**: シングルトンの状態がテスト間で漯れる問題

### TODO/フォローアップ追加

- [ ] マルチサーバー環境でのシングルトンの振る舞い調査
- [ ] シングルトン状態のスレッド安全性検証
- [ ] テスト環境でのシングルトンリセット戦略
- [ ] パフォーマンス監視でのシングルトンアクセスパターン
- [ ] 設定ホットリロードとシングルトンの統合