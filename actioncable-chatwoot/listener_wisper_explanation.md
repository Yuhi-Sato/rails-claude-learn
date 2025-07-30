# Listenerとは？Wisperパターン詳細解説

## 🤔 **「Listener」の正体**

**Listener**とは、ChatwootでWisper（ウィスパー）gemを使って実装された**イベント駆動アーキテクチャ**のコンポーネントです。

## 🏗️ **Wisperパターンの仕組み**

### **基本構造**
```ruby
# 1. Publisher（イベント発信者）
class BaseDispatcher
  include Wisper::Publisher  # ← これでイベントを発信できる
end

# 2. Listener（イベント受信者）
class ActionCableListener < BaseListener
  def message_created(event)  # ← イベント名と同じメソッド名で自動実行
    # ActionCableでブロードキャスト処理
  end
end

# 3. 登録（配線）
dispatcher.subscribe(ActionCableListener.instance)
```

### **実際のフロー**
```
Model変更 → Rails.configuration.dispatcher.dispatch()
    ↓
Dispatcher → SyncDispatcher & AsyncDispatcher
    ↓
Wisper::Publisher.publish() → 登録済みListenerに通知
    ↓
ActionCableListener.message_created(event) 自動実行
    ↓
ActionCable.server.broadcast() でWebSocketに配信
```

## 📋 **ChatwootでのDispatcher設計**

### **2層構造の配信システム**

#### **SyncDispatcher（同期処理）**
```ruby
class SyncDispatcher < BaseDispatcher
  def listeners
    [ActionCableListener.instance, AgentBotListener.instance]
  end
end
```
- **即座に実行**される重要な処理
- **ActionCableListener**: リアルタイム通信（最優先）
- **AgentBotListener**: ボット応答（即時）

#### **AsyncDispatcher（非同期処理）**
```ruby
class AsyncDispatcher < BaseDispatcher
  def listeners
    [
      AutomationRuleListener.instance,    # 自動化ルール
      CampaignListener.instance,          # キャンペーン
      NotificationListener.instance,      # 通知
      WebhookListener.instance,          # Webhook送信
      # など10個以上のListener
    ]
  end
end
```
- **Sidekiqで後処理**される機能
- UI応答を遅らせない設計

## 🎯 **ActionCableListenerの役割**

### **イベント→ブロードキャスト変換器**
```ruby
class ActionCableListener < BaseListener
  # Wisperイベント受信 → ActionCableブロードキャスト変換
  def message_created(event)
    message, account = extract_message_and_account(event)
    tokens = user_tokens(account, conversation.inbox.members)
    
    # ActionCableBroadcastJobで非同期ブロードキャスト
    broadcast(account, tokens, MESSAGE_CREATED, message.push_event_data)
  end
end
```

### **40以上のイベントハンドラ**
- `message_created`, `message_updated`
- `conversation_created`, `conversation_status_changed`
- `notification_created`, `notification_updated`
- `presence.update`, `assignee_changed`
- など...

## 🔄 **イベント発生の起点**

### **モデルでのイベント発信**
```ruby
# app/models/conversation.rb
def dispatch_update_event
  Rails.configuration.dispatcher.dispatch(
    CONVERSATION_UPDATED, 
    Time.zone.now, 
    conversation: self
  )
end
```

### **コントローラーでのイベント発信**
```ruby
# メッセージ作成API
def create
  @message = conversation.messages.create!(message_params)
  # ↓ 自動的にイベント発信される（モデルのコールバック）
end
```

## 🚀 **なぜWisperパターンを使うのか？**

### **1. 疎結合設計**
```ruby
# ❌ 密結合（悪い例）
class MessageController
  def create
    message = Message.create!(params)
    ActionCable.server.broadcast(...)  # 直接依存
    Webhook.send_notification(...)     # 直接依存
    AutomationRule.process(...)        # 直接依存
  end
end

# ✅ 疎結合（Wisperパターン）
class MessageController  
  def create
    message = Message.create!(params)
    # ↓ イベント発信のみ。処理の詳細は知らない
    dispatcher.dispatch(:message_created, Time.now, message: message)
  end
end
```

### **2. 機能追加が容易**
```ruby
# 新機能追加時
class SlackNotificationListener < BaseListener
  def message_created(event)
    # Slack通知処理
  end
end

# AsyncDispatcherに追加するだけ！
def listeners
  [...existing_listeners, SlackNotificationListener.instance]
end
```

### **3. テストしやすさ**
```ruby
RSpec.describe ActionCableListener do
  it 'broadcasts message_created event' do
    event = build_event(:message_created, message: message)
    expect(ActionCableBroadcastJob).to receive(:perform_later)
    
    ActionCableListener.instance.message_created(event)
  end
end
```

## 🎛️ **設定と初期化**

### **Rails起動時の配線**
```ruby
# config/initializers/event_handlers.rb
Rails.application.configure do
  config.to_prepare do
    Rails.configuration.dispatcher = Dispatcher.instance
    Rails.configuration.dispatcher.load_listeners  # ← 全Listenerを登録
  end
end
```

### **Dispatcher階層**
```
Dispatcher (統括)
├── SyncDispatcher (即時実行)
│   ├── ActionCableListener ← リアルタイム通信
│   └── AgentBotListener    ← ボット応答
└── AsyncDispatcher (非同期実行)
    ├── WebhookListener     ← 外部API呼び出し
    ├── NotificationListener ← メール通知
    └── その他10以上のListener
```

## 💡 **設計の巧妙さ**

### **同期vs非同期の使い分け**
- **ActionCableListener**: 同期実行（即座にWebSocketブロードキャスト）
- **WebhookListener**: 非同期実行（外部API呼び出しでUIを遅らせない）

### **単一責任の原則**
- **ActionCableListener**: WebSocket通信専用
- **NotificationListener**: メール/プッシュ通知専用
- **WebhookListener**: 外部Webhook送信専用

### **拡張性**
Enterprise版では`ActionCableListener.prepend_mod_with('ActionCableListener')`で機能拡張

## 🎯 **まとめ：Listenerの本質**

**Listener = イベント処理の専門家**

1. **Wisperパターン**でモデル変更イベントを受信
2. **専門分野の処理**を実行（ActionCable、Webhook、通知など）
3. **疎結合設計**で機能追加・テストが容易
4. **同期/非同期**の使い分けでパフォーマンス最適化

ChatwootのListenerは、単なる「イベント処理クラス」ではなく、**スケーラブルで保守しやすいアーキテクチャを実現する設計パターン**の核心部分なのです！