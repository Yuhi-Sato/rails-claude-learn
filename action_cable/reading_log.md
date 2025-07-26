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

# Action Cable 読書ログ

## Session 7: WebSocket接続からConnectionインスタンス作成まで

**目的**: WebSocketの接続でConnectionインスタンスが作成される過程の理解

### WebSocket接続フローの完全解析

#### 1. HTTP WebSocketアップグレードリクエストの処理

WebSocket接続の開始はHTTPリクエストから始まります：

1. **Rails Router/Rack処理**
   - クライアントがWebSocketアップグレードリクエストを送信
   - Action Cableのマウントポイント（通常 `/cable`）でキャッチ

2. **ActionCable::Server::Base#call**
   - Rackアプリケーションとしてリクエストを受信
   - `config.connection_class.call.new(self, env).process` でConnectionインスタンス作成・処理

#### 2. Connectionクラスの動的解決メカニズム (`base.rb:41`)

```ruby
config.connection_class.call.new(self, env).process
```

**重要な理解**:
- `connection_class` は **Procオブジェクト** (デフォルト: `-> { ActionCable::Connection::Base }`)
- Rails環境では `-> { "ApplicationCable::Connection".safe_constantize || ActionCable::Connection::Base }`
- `.call` でクラスを動的に解決してから `.new` でインスタンス作成
- これによりユーザー定義の `ApplicationCable::Connection` を優先して使用

#### 3. Connection::Baseインスタンスの作成過程 (`base.rb:67-79`)

```ruby
def initialize(server, env, coder: ActiveSupport::JSON)
  @server, @env, @coder = server, env, coder
  
  @worker_pool = server.worker_pool
  @logger = new_tagged_logger
  
  @websocket      = ActionCable::Connection::WebSocket.new(env, self, event_loop)
  @subscriptions  = ActionCable::Connection::Subscriptions.new(self)
  @message_buffer = ActionCable::Connection::MessageBuffer.new(self)
  
  @_internal_subscriptions = nil
  @started_at = Time.now
end
```

**初期化時の依存関係構築**:
- `@websocket`: WebSocketプロキシを作成（`env`, `self`, `event_loop`を渡す）
- `@subscriptions`: チャンネルサブスクリプション管理
- `@message_buffer`: WebSocketメッセージのバッファリング
- `@worker_pool`: サーバーのWorker Poolを参照

#### 3. WebSocket抽象化レイヤーの構造

**3層構造のWebSocket実装**:

1. **Connection::WebSocket** (`web_socket.rb`)
   - 外部APIを最小限に抑えるためのプロキシクラス
   - `possible?`, `protocol`, `transmit`, `close`, `rack_response`メソッドを提供
   - 実際のWebSocketロジックは`ClientSocket`に移譲

2. **Connection::ClientSocket** (`client_socket.rb`)
   - `faye-websocket-ruby`ベースの実装
   - WebSocketプロトコルとステート管理
   - `::WebSocket::Driver.rack`を使用したWebSocketドライバー作成
   
3. **Connection::Stream**
   - I/Oの実際の管理
   - Event Loopとの統合
   - Rackソケットのハイジャック処理

#### 4. WebSocketドライバーの初期化 (`client_socket.rb:36-57`)

```ruby
def initialize(env, event_target, event_loop, protocols)
  @env          = env
  @event_target = event_target  # Connection::Baseインスタンス
  @event_loop   = event_loop
  
  @url = ClientSocket.determine_url(@env)
  
  @driver = @driver_started = nil
  @close_params = ["", 1006]
  @ready_state = CONNECTING
  
  # WebSocketドライバーを作成
  @driver = ::WebSocket::Driver.rack(self, protocols: protocols)
  
  # イベントハンドラーを設定
  @driver.on(:open)    { |e| open }
  @driver.on(:message) { |e| receive_message(e.data) }
  @driver.on(:close)   { |e| begin_close(e.reason, e.code) }
  @driver.on(:error)   { |e| emit_error(e.message) }
  
  @stream = ActionCable::Connection::Stream.new(@event_loop, self)
end
```

**重要な設計パターン**:
- `@event_target`としてConnection::Baseインスタンスを保持
- WebSocketイベントを対応するConnection::Baseメソッドに委譲
- `::WebSocket::Driver.rack`でプロトコル準拠のWebSocketドライバー作成

#### 5. Connection処理フロー (`base.rb:85-93`)

```ruby
def process
  logger.info started_request_message
  
  if websocket.possible? && allow_request_origin?
    respond_to_successful_request
  else
    respond_to_invalid_request
  end
end
```

**検証ステップ**:
1. WebSocketアップグレードが可能かチェック
2. Origin検証でCSRF攻撃を防止
3. 成功時：`websocket.rack_response`でWebSocketハンドシェイク完了
4. 失敗時：404レスポンスで接続拒否

#### 6. WebSocket接続確立後の初期化フロー

**a) WebSocketドライバー開始** (`client_socket.rb:59-69`):
```ruby
def start_driver
  return if @driver.nil? || @driver_started
  @stream.hijack_rack_socket  # Rackソケットをハイジャック
  
  if callback = @env["async.callback"]
    callback.call([101, {}, @stream])  # HTTP 101 Switching Protocols
  end
  
  @driver_started = true
  @driver.start
end
```

**b) Connection開始処理** (`base.rb:199-209`):
```ruby
def handle_open
  @protocol = websocket.protocol
  connect if respond_to?(:connect)          # ユーザー定義connect処理
  subscribe_to_internal_channel
  send_welcome_message
  
  message_buffer.process!                   # バッファーされたメッセージ処理
  server.add_connection(self)               # サーバーに接続を登録
rescue ActionCable::Connection::Authorization::UnauthorizedError
  close(reason: ActionCable::INTERNAL[:disconnect_reasons][:unauthorized], reconnect: false) if websocket.alive?
end
```

#### 7. イベント委譲パターン

WebSocketイベントがConnection::Baseメソッドに委譲される仕組み：

- `@driver.on(:open)` → `open` → `@event_target.on_open` → `Connection::Base#handle_open`
- `@driver.on(:message)` → `receive_message` → `@event_target.on_message` → `Connection::Base#message_buffer.append`
- `@driver.on(:close)` → `begin_close` → `@event_target.on_close` → `Connection::Base#handle_close`
- `@driver.on(:error)` → `emit_error` → `@event_target.on_error` → `Connection::Base#on_error`

### 完全な接続フロー図

```
1. HTTP WebSocket Upgrade Request
        ↓
2. ActionCable::Server::Base#call
        ↓
3. Connection::Base.new(server, env)
        ↓
4. Connection::WebSocket.new(env, connection, event_loop)
        ↓
5. Connection::ClientSocket.new(env, connection, event_loop, protocols)
        ↓
6. ::WebSocket::Driver.rack(client_socket)
        ↓
7. Connection::Stream.new(event_loop, client_socket)
        ↓
8. connection.process (WebSocket upgrade validation)
        ↓
9. websocket.rack_response → client_socket.start_driver
        ↓
10. stream.hijack_rack_socket (HTTP → WebSocket conversion)
        ↓
11. driver.start → WebSocket handshake completion
        ↓
12. driver.on(:open) → connection.handle_open
        ↓
13. user.connect + server.add_connection(connection)
```

### 主要な学習ポイント

1. **3層WebSocket抽象化**: WebSocket → ClientSocket → Stream
2. **イベント駆動アーキテクチャ**: WebSocketイベントをConnection::Baseに委譲
3. **プロトコル準拠**: `::WebSocket::Driver.rack`でRFC準拠のWebSocket実装
4. **Rackソケットハイジャック**: `@stream.hijack_rack_socket`でHTTP接続をWebSocketに変換
5. **非同期初期化**: `handle_open`でのユーザー認証と接続登録
6. **Connection/Channel分離**: Connectionは接続管理、Channelはビジネスロジック
7. **セキュリティ考慮**: Origin検証とUnauthorizedError処理

---

## セッション8: WebSocket接続フローの完全解析 - 追加調査
- 日付/時間: 2025-01-26 WebSocket接続フロー統合調査
- 対象範囲: actioncable/lib/action_cable/connection/base.rb, client_socket.rb
- 目的: WebSocket接続からConnectionインスタンス作成までの完全なフローを文書化

### WebSocket接続フローの詳細解析

#### HTTPからWebSocketへの変換プロセス

**1. HTTPリクエスト受信**
```
GET /cable HTTP/1.1
Connection: Upgrade
Upgrade: websocket
```

**2. Rails Router/Rackによる処理**
- Action Cableのマウントポイントでキャッチ
- `ActionCable::Server::Base#call(env)` が呼び出される

**3. Connection::Base インスタンス作成** (`base.rb:67-79`)
```ruby
def initialize(server, env, coder: ActiveSupport::JSON)
  @server, @env, @coder = server, env, coder
  @worker_pool = server.worker_pool
  @logger = new_tagged_logger
  
  # 重要: WebSocket抽象化レイヤーの構築
  @websocket      = ActionCable::Connection::WebSocket.new(env, self, event_loop)
  @subscriptions  = ActionCable::Connection::Subscriptions.new(self)
  @message_buffer = ActionCable::Connection::MessageBuffer.new(self)
end
```

#### 3層WebSocket抽象化アーキテクチャ

**レイヤー1: Connection::WebSocket** (プロキシ)
- 外部APIの簡潔性を保つためのプロキシクラス
- `possible?`, `protocol`, `transmit`, `close`, `rack_response` を提供
- 実際の処理は ClientSocket に移譲

**レイヤー2: Connection::ClientSocket** (WebSocketプロトコル)
- `faye-websocket-ruby` ベースの実装
- `::WebSocket::Driver.rack` でプロトコル準拠のドライバー作成
- WebSocketステート管理 (CONNECTING, OPEN, CLOSING, CLOSED)

**レイヤー3: Connection::Stream** (I/O管理)
- Rackソケットのハイジャック処理
- Event Loopとの統合
- 実際のTCP/WebSocketレベルのI/O

#### WebSocketドライバーの初期化 (`client_socket.rb:36-57`)

```ruby
def initialize(env, event_target, event_loop, protocols)
  @env          = env
  @event_target = event_target  # Connection::Baseインスタンス
  @event_loop   = event_loop
  
  # WebSocketドライバー作成
  @driver = ::WebSocket::Driver.rack(self, protocols: protocols)
  
  # イベント委譲の設定
  @driver.on(:open)    { |e| open }
  @driver.on(:message) { |e| receive_message(e.data) }
  @driver.on(:close)   { |e| begin_close(e.reason, e.code) }
  @driver.on(:error)   { |e| emit_error(e.message) }
end
```

#### WebSocketハンドシェイクとConnection確立

**1. 接続検証** (`base.rb:85-93`)
```ruby
def process
  if websocket.possible? && allow_request_origin?
    respond_to_successful_request  # WebSocketハンドシェイク
  else
    respond_to_invalid_request     # 404レスポンス
  end
end
```

**2. WebSocketドライバー開始** (`client_socket.rb:59-69`)
```ruby
def start_driver
  @stream.hijack_rack_socket  # HTTP接続をハイジャック
  
  if callback = @env["async.callback"]
    callback.call([101, {}, @stream])  # HTTP 101 Switching Protocols
  end
  
  @driver.start
end
```

**3. Connection初期化完了** (`base.rb:199-209`)
```ruby
def handle_open
  @protocol = websocket.protocol
  connect if respond_to?(:connect)      # ユーザー定義認証
  subscribe_to_internal_channel
  send_welcome_message
  
  message_buffer.process!               # バッファー処理開始
  server.add_connection(self)           # サーバーに接続登録
end
```

#### イベント委譲メカニズム

WebSocketイベントがConnection::Baseに委譲される仕組み:

```
WebSocketドライバー → ClientSocket → Connection::Base

@driver.on(:open)    → open()          → @event_target.on_open()    → handle_open()
@driver.on(:message) → receive_message → @event_target.on_message() → message_buffer.append()
@driver.on(:close)   → begin_close()   → @event_target.on_close()   → handle_close()
@driver.on(:error)   → emit_error()    → @event_target.on_error()   → ログ出力
```

### 重要な設計決定の理解

#### 1. なぜ3層抽象化なのか？
- **WebSocket**: 簡潔なAPI、テスト容易性
- **ClientSocket**: WebSocketプロトコル準拠、faye-websocket統合
- **Stream**: Event Loop統合、Rackハイジャック処理

#### 2. イベント駆動アーキテクチャの利点
- WebSocketライフサイクルとConnection処理の分離
- 非同期イベント処理の統一
- テスタビリティの向上

#### 3. MessageBufferの重要性
- WebSocket確立とConnection初期化のタイミングギャップを解決
- メッセージの順序保証
- 初期化中のメッセージロストを防止

### 完全な接続フロー図

```
1. HTTP WebSocket Upgrade Request
        ↓
2. ActionCable::Server::Base#call(env)
        ↓
3. config.connection_class.call - クラス動的解決
        ↓
4. Connection::Base.new(server, env) - 依存関係構築
        ↓
5. Connection::WebSocket.new() - プロキシ作成
        ↓
6. Connection::ClientSocket.new() - ドライバー初期化
        ↓
7. ::WebSocket::Driver.rack() - プロトコル準拠ドライバー
        ↓
8. Connection::Stream.new() - I/O管理
        ↓
9. connection.process() - 接続検証
        ↓
10. websocket.rack_response() → start_driver()
        ↓
11. stream.hijack_rack_socket() - HTTP→WebSocket変換
        ↓
12. driver.start() → WebSocketハンドシェイク
        ↓
13. driver.on(:open) → handle_open()
        ↓
14. user.connect() + server.add_connection()
```

### 学習ポイントの統合

1. **プロトコル準拠**: RFC準拠のWebSocket実装を `::WebSocket::Driver.rack` で実現
2. **責任分離**: HTTP処理、WebSocketプロトコル、I/O管理を適切に分離
3. **Event Loop統合**: 非ブロッキングI/Oとイベント駆動処理
4. **セキュリティ**: Origin検証、認証失敗時の適切な切断処理
5. **タイミング制御**: MessageBufferによる初期化タイミング問題の解決

---

## セッション9: WebSocket接続後のサブスクリプション確立プロセス
- 日付/時間: 2025-01-26 サブスクリプション確立調査
- 対象範囲: connection/subscriptions.rb, channel/base.rb, action_cable.js
- 目的: 接続確立後のチャンネルサブスクリプション処理フローを理解

### サブスクリプション確立の完全フロー

#### 1. クライアントサイド - JavaScript での開始 (`action_cable.js`)

**ステップ1: Consumer による Subscription 作成**
```javascript
// ユーザーコード
const consumer = ActionCable.createConsumer();
const subscription = consumer.subscriptions.create("ChatChannel", {
  received: function(data) { ... }
});
```

**ステップ2: Subscriptions.create() 処理** (`action_cable.js:373-379`)
```javascript
create(channelName, mixin) {
  const params = typeof channel === "object" ? channel : { channel: channel };
  const subscription = new Subscription(this.consumer, params, mixin);
  return this.add(subscription);
}
```

**ステップ3: Subscription インスタンス作成** (`action_cable.js:311-315`)
```javascript
constructor(consumer, params = {}, mixin) {
  this.consumer = consumer;
  this.identifier = JSON.stringify(params);  // {"channel":"ChatChannel"}
  extend(this, mixin);
}
```

**ステップ4: Subscriptions.add() でサブスクリプション登録** (`action_cable.js:381-386`)
```javascript
add(subscription) {
  this.subscriptions.push(subscription);
  this.consumer.ensureActiveConnection();     // 接続確保
  this.notify(subscription, "initialized");  // initialized コールバック
  this.subscribe(subscription);              // 実際のサブスクライブ送信
  return subscription;
}
```

**ステップ5: サブスクライブ コマンド送信** (`action_cable.js:425-429`)
```javascript
subscribe(subscription) {
  if (this.sendCommand(subscription, "subscribe")) {
    this.guarantor.guarantee(subscription);   // 再購読保証
  }
}

sendCommand(subscription, command) {
  return this.consumer.send({
    command: command,                         // "subscribe"
    identifier: subscription.identifier      // JSON文字列
  });
}
```

#### 2. サーバーサイド - WebSocket メッセージ受信処理

**ステップ6: WebSocket メッセージ受信** (`connection/base.rb:97-113`)
```ruby
def receive(websocket_message)
  send_async :dispatch_websocket_message, websocket_message
end

def dispatch_websocket_message(websocket_message)
  if websocket.alive?
    handle_channel_command decode(websocket_message)
  end
end

def handle_channel_command(payload)
  run_callbacks :command do
    subscriptions.execute_command payload
  end
end
```

**ステップ7: Subscriptions.execute_command()** (`connection/subscriptions.rb:20-31`)
```ruby
def execute_command(data)
  case data["command"]
  when "subscribe"   then add data           # サブスクライブ処理
  when "unsubscribe" then remove data
  when "message"     then perform_action data
  else
    logger.error "Received unrecognized command in #{data.inspect}"
  end
end
```

**ステップ8: Subscriptions.add() - チャンネル作成** (`connection/subscriptions.rb:33-48`)
```ruby
def add(data)
  id_key = data["identifier"]                              # JSON文字列
  id_options = ActiveSupport::JSON.decode(id_key).with_indifferent_access
  
  return if subscriptions.key?(id_key)                     # 重複チェック
  
  subscription_klass = id_options[:channel].safe_constantize  # クラス解決
  
  if subscription_klass && ActionCable::Channel::Base > subscription_klass
    subscription = subscription_klass.new(connection, id_key, id_options)
    subscriptions[id_key] = subscription                   # 登録
    subscription.subscribe_to_channel                      # チャンネル購読開始
  else
    logger.error "Subscription class not found: #{id_options[:channel].inspect}"
  end
end
```

#### 3. チャンネル購読確立処理

**ステップ9: Channel インスタンス作成と購読処理** (`channel/base.rb:191-198`)
```ruby
def subscribe_to_channel
  run_callbacks :subscribe do
    subscribed                                   # ユーザー定義 subscribed コールバック
  end
  
  reject_subscription if subscription_rejected?  # 拒否チェック
  ensure_confirmation_sent                       # 確認送信
end
```

**ステップ10: ユーザー定義 subscribed コールバック実行**
```ruby
# ユーザー定義チャンネル例
class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "chat_room_#{params[:room_id]}"  # ストリーム購読
  end
end
```

**ステップ11: サブスクリプション確認送信** (`channel/base.rb`)
```ruby
def ensure_confirmation_sent
  return if subscription_rejected? || @confirmation_sent
  
  logger.info "#{self.class.name} is transmitting the subscription confirmation"
  connection.transmit identifier: @identifier, 
                      type: ActionCable::INTERNAL[:message_types][:confirmation]
  @confirmation_sent = true
end
```

#### 4. クライアントサイド - 確認受信処理

**ステップ12: 確認メッセージ受信** (`action_cable.js:430-433`)
```javascript
confirmSubscription(identifier) {
  logger.log(`Subscription confirmed ${identifier}`);
  this.findAll(identifier).map((subscription => 
    this.guarantor.forget(subscription)       // 再購読保証から除外
  ));
}
```

**ステップ13: connected コールバック実行**
```javascript
// ユーザーコード
consumer.subscriptions.create("ChatChannel", {
  connected: function() {
    console.log("Connected to ChatChannel");   // 購読完了
  },
  received: function(data) { ... }
});
```

### サブスクリプション確立の重要メカニズム

#### 1. **識別子 (identifier) による管理**
- クライアント: `JSON.stringify(params)` で生成
- サーバー: JSON パース後にチャンネルクラス解決
- 同一 identifier での重複購読を防止

#### 2. **SubscriptionGuarantor による信頼性**
- 購読失敗時の自動再試行 (500ms間隔)
- 接続断後の再購読保証
- 確認受信まで再試行を継続

#### 3. **非同期確認メカニズム**
- サーバー: `subscribed` コールバック成功後に確認送信
- クライアント: 確認受信後に `connected` コールバック実行
- 購読拒否時は `rejected` コールバック実行

#### 4. **エラーハンドリング**
- 存在しないチャンネルクラス: エラーログ出力
- 購読拒否: `reject` メソッドで明示的拒否可能
- 接続切断時: 自動的な全サブスクリプション解除

### 完全なサブスクリプション確立フロー図

```
1. consumer.subscriptions.create("ChatChannel", callbacks)
        ↓
2. new Subscription(consumer, {channel: "ChatChannel"}, callbacks)
        ↓
3. subscriptions.add(subscription) - 配列に追加
        ↓
4. subscription.subscribe() - "subscribe" コマンド送信
        ↓
5. WebSocket メッセージ → connection.receive()
        ↓
6. subscriptions.execute_command({command: "subscribe", identifier: "..."})
        ↓
7. subscriptions.add() - チャンネルクラス解決
        ↓
8. ChatChannel.new(connection, identifier, params)
        ↓
9. channel.subscribe_to_channel() - 購読処理開始
        ↓
10. channel.subscribed() - ユーザー定義コールバック実行
        ↓
11. channel.ensure_confirmation_sent() - 確認メッセージ送信
        ↓
12. subscriptions.confirmSubscription(identifier) - 確認受信
        ↓
13. subscription.connected() - クライアント側 connected コールバック
```

### 学習ポイント

1. **双方向確認プロトコル**: クライアント要求 → サーバー処理 → 確認応答
2. **動的クラス解決**: JSON identifier からチャンネルクラスを動的作成
3. **非同期処理**: Worker Pool を使用した購読処理の非同期化
4. **信頼性保証**: SubscriptionGuarantor による再試行メカニズム
5. **ライフサイクル管理**: initialized → subscribed → connected の段階的処理

---

## セッション10: Event Loopアーキテクチャとクライアント接続待ち受け処理
- 日付/時間: 2025-01-26 Event Loop詳細調査
- 対象範囲: connection/stream_event_loop.rb, connection/stream.rb, channel/streams.rb
- 目的: チャンネルにおけるクライアント接続待ち受けとイベント処理の流れを理解

### Action Cable Event Loopの核心アーキテクチャ

#### 1. StreamEventLoopの基本構造 (`stream_event_loop.rb`)

**Event Loopの初期化**
```ruby
def initialize
  @nio = @executor = @thread = nil    # 遅延初期化
  @map = {}                           # IO → Stream のマッピング
  @stopping = false                   # 停止フラグ
  @todo = Queue.new                   # タスクキュー
  @spawn_mutex = Mutex.new            # スレッド作成保護
end
```

**NIO-based I/O多重化**
```ruby
def spawn
  @nio ||= NIO::Selector.new                    # ノンブロッキングI/Oセレクター
  @executor ||= Concurrent::ThreadPoolExecutor.new(
    name: "ActionCable-streamer",
    min_threads: 1,
    max_threads: 10,                            # Stream処理用スレッドプール
    max_queue: 0,
  )
  @thread = Thread.new { run }                  # メインイベントループスレッド
end
```

#### 2. WebSocket接続のEvent Loop統合フロー

**ステップ1: WebSocket接続確立時のI/O登録**
```ruby
# stream.rb:106
def hijack_rack_socket
  @rack_hijack_io = @socket_object.env["rack.hijack"].call
  @event_loop.attach(@rack_hijack_io, self)           # Event LoopにI/O登録
end

# stream_event_loop.rb:30-36
def attach(io, stream)
  @todo << lambda do
    @map[io] = @nio.register(io, :r)                  # 読み取り監視登録
    @map[io].value = stream                           # StreamオブジェクトをIOにバインド
  end
  wakeup                                              # Event Loopを起動
end
```

**ステップ2: メインEvent Loopでの接続待ち受け**
```ruby
# stream_event_loop.rb:87-134
def run
  loop do
    return if @stopping
    
    # タスクキューの処理
    until @todo.empty?
      @todo.pop(true).call
    end
    
    # I/O多重化による接続監視
    next unless monitors = @nio.select              # ノンブロッキングI/O待機
    
    monitors.each do |monitor|
      io = monitor.io
      stream = monitor.value                        # 対応するStreamオブジェクト
      
      # 書き込み可能時の処理
      if monitor.writable?
        if stream.flush_write_buffer                # バッファーをフラッシュ
          monitor.interests = :r                    # 読み取り専用に戻す
        end
      end
      
      # 読み取り可能時の処理
      if monitor.readable?
        incoming = io.read_nonblock(4096, exception: false)
        case incoming
        when :wait_readable
          next
        when nil
          stream.close                              # クライアント切断
        else
          stream.receive incoming                   # データ受信処理
        end
      end
    end
  end
end
```

#### 3. チャンネルストリーミングとEvent Loop統合

**ストリーム購読の非同期処理** (`streams.rb:103-107`)
```ruby
def stream_from(broadcasting, callback = nil, coder: nil, &block)
  # ... ハンドラー準備 ...
  
  connection.server.event_loop.post do              # Event Loopに投稿
    pubsub.subscribe(broadcasting, handler, lambda do
      ensure_confirmation_sent                      # 購読確認
      logger.info "#{self.class.name} is streaming from #{broadcasting}"
    end)
  end
end
```

**Event Loopでの非同期実行フロー**
```ruby
# stream_event_loop.rb:23-28
def post(task = nil, &block)
  task ||= block
  spawn                                             # Event Loopスレッド起動
  @executor << task                                 # ThreadPoolExecutorに投稿
end
```

#### 4. WebSocketデータの双方向処理

**クライアント → サーバー (データ受信)**
```ruby
# Event Loopが検知 → stream.receive(data) → client_socket.parse(data)
def receive(data)
  @socket_object.parse(data)                        # WebSocketプロトコル処理
end

# WebSocketドライバーがパース → Connection#on_message → message_buffer
```

**サーバー → クライアント (データ送信)**
```ruby
# stream.rb:37-70
def write(data)
  if @write_lock.try_lock
    # 直接書き込み試行
    written = @rack_hijack_io.write_nonblock(data, exception: false)
    case written
    when :wait_writable
      # バッファーリング必要
    when data.bytesize
      return data.bytesize                          # 即座に送信完了
    else
      @write_head = data.byteslice(written, data.bytesize)
      @event_loop.writes_pending @rack_hijack_io   # 書き込み監視要求
    end
  end
  
  @write_buffer << data                             # バッファーに追加
  @event_loop.writes_pending @rack_hijack_io       # Event Loopに通知
end
```

#### 5. ハートビートとコネクション管理

**定期ハートビート送信** (`connections.rb:34-36`)
```ruby
def setup_heartbeat_timer
  @heartbeat_timer ||= event_loop.timer(BEAT_INTERVAL) do
    event_loop.post { connections.each(&:beat) }    # 全接続にpingを送信
  end
end
```

**タイマー実装** (`stream_event_loop.rb:19-21`)
```ruby
def timer(interval, &block)
  Concurrent::TimerTask.new(execution_interval: interval, &block).tap(&:execute)
end
```

### Event Loopアーキテクチャの設計思想

#### 1. **Single-threaded Event Loop + Thread Pool**
```
┌─────────────────────────────────────────────────────────┐
│ StreamEventLoop (1つのメインスレッド)                      │
├─────────────────────────────────────────────────────────┤
│ • NIO::Selector で全WebSocket I/Oを多重化                 │
│ • ノンブロッキングI/Oで高い並行性                           │
│ • @todo Queue でタスクのシリアル実行                       │
└─────────────────────────────────────────────────────────┘
                        ↓ 重い処理を移譲
┌─────────────────────────────────────────────────────────┐
│ Concurrent::ThreadPoolExecutor (1-10スレッド)             │
├─────────────────────────────────────────────────────────┤
│ • pub/sub購読処理                                         │
│ • ストリーミングハンドラー実行                             │
│ • コールバック実行                                         │
└─────────────────────────────────────────────────────────┘
```

#### 2. **責任分離パターン**
- **Event Loop**: I/O待機、接続管理、軽量タスク実行
- **Worker Pool**: Channel処理、データベースアクセス、重い処理
- **Stream**: 個別WebSocket接続のI/O管理

#### 3. **非同期処理の統合**
```ruby
# すべての非同期操作がEvent Loopを通る
event_loop.post { pubsub.subscribe(...) }        # ストリーム購読
event_loop.post { connections.each(&:beat) }     # ハートビート
event_loop.attach(io, stream)                    # WebSocket I/O登録
event_loop.writes_pending(io)                    # 書き込み要求
```

### パフォーマンスとスケーラビリティ

#### 1. **高並行接続処理**
- **1つのEvent Loop** で数千のWebSocket接続を効率的に処理
- **NIOセレクター** でシステムコール最小化
- **ノンブロッキングI/O** でCPU効率最大化

#### 2. **メモリ効率**
```ruby
@map = {}                                         # IO → Stream マッピング
@write_buffer = Queue.new                         # 接続毎の書き込みバッファー
monitors.each { |monitor| ... }                  # アクティブな接続のみ処理
```

#### 3. **バックプレッシャー対応**
- 書き込みバッファーでクライアント送信レート制御
- `write_nonblock` で送信可能性チェック
- `:wait_writable` でフロー制御

### Event Loop使用パターン

#### 1. **ストリーム購読** (最重要)
```ruby
event_loop.post do
  pubsub.subscribe(broadcasting, handler, confirmation_callback)
end
```

#### 2. **内部チャンネル管理**
```ruby
event_loop.post { pubsub.subscribe(internal_channel, callback) }
event_loop.post { pubsub.unsubscribe(channel, callback) }
```

#### 3. **アダプター統合**
```ruby
# Redis, PostgreSQL, Async すべてのアダプターが event_loop.post を使用
@event_loop.post { super }                       # コールバック実行の非同期化
```

### 学習ポイント

1. **Event-driven Architecture**: すべての非同期処理がEvent Loopを中心に統合
2. **NIO-based I/O Multiplexing**: 高効率なWebSocket接続管理
3. **Thread Pool Integration**: I/O処理と重い処理の適切な分離
4. **Flow Control**: バックプレッシャーとバッファーリングによる安定性
5. **Unified Async Model**: ストリーム、ハートビート、アダプターの統一的な非同期処理

**次のステップ**: 実際のパフォーマンス測定とスケーラビリティ検証
