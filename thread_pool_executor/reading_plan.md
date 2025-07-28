# 読解計画書 - ThreadPoolExecutor

## 1. 対象コードベースの俯瞰

### リポジトリ構成
- `lib/concurrent-ruby/concurrent/executor/` - Executorクラス群
- `spec/concurrent/executor/` - テストファイル群

### 主要エントリポイント
- `ThreadPoolExecutor` - 公開クラス（プラットフォーム別実装のファサード）
- `RubyThreadPoolExecutor` - MRI/TruffleRuby用実装
- `RubyExecutorService` - 基底クラス
- `AbstractExecutorService` - 抽象基底クラス

### 重要モジュール・依存関係
```
ThreadPoolExecutor (facade)
↓
RubyThreadPoolExecutor 
↓
RubyExecutorService 
↓  
AbstractExecutorService / ExecutorService
```

## 2. 読解ルートマップ

### 2.1 優先ルート（必ず読む）

1. **ExecutorService (`executor_service.rb`)** : `<<` メソッドの定義場所
   - 仮説: `<<` は `post` メソッドを呼び出すだけのラッパー

2. **RubyExecutorService (`ruby_executor_service.rb`)** : `post` メソッドの実装
   - 仮説: 排他制御（synchronize）を使って `ns_execute` を呼び出し

3. **RubyThreadPoolExecutor (`ruby_thread_pool_executor.rb`)** : メイン実装
   - `ns_initialize` : インスタンス生成時の初期化処理
   - `ns_execute` : タスク実行の中心ロジック
   - `ns_assign_worker` : ワーカーへのタスク割り当て
   - `ns_enqueue` : タスクキューへの追加
   - 各種 `synchronize` ブロック : 排他制御ポイント

4. **Worker内部クラス** : ワーカースレッドの動作
   - `initialize` : ワーカースレッド作成
   - `<<` : タスクメッセージの受信
   - `create_worker` : ワーカーメインループ
   - `run_task` : タスク実行処理

### 2.2 補助ルート（必要に応じて）

- **AbstractExecutorService** : 基底クラスの状態管理
- **テストファイル** : 実際の使用例と期待動作
- **synchronization関連モジュール** : 排他制御の詳細実装

## 3. トレース方針

### 呼び出し追跡
- **grep/ripgrep** : メソッド定義と呼び出し箇所の特定
- **継承関係追跡** : `super` 呼び出しを辿る
- **排他制御箇所特定** : `synchronize` キーワード検索

### 確認ポイント
- **ログ/デバッグ** : 各段階での内部状態変化
- **スレッドID追跡** : どのスレッドがどの処理を実行しているか
- **タイミング測定** : 非同期性の確認

## 4. 実験計画

### 基本動作確認
```ruby
# 最小限のテストコード
executor = Concurrent::ThreadPoolExecutor.new(min_threads: 2, max_threads: 4)
executor << proc { puts "Task executed in thread: #{Thread.current}" }
```

### 排他制御確認
```ruby
# 競合状態を意図的に発生させるテスト
executor = Concurrent::ThreadPoolExecutor.new(min_threads: 1, max_threads: 1)
100.times do |i|
  executor << proc { puts "Task #{i}" }
end
```

### 内部状態追跡
- デバッグ出力を追加した改造版での動作確認
- スレッドダンプでワーカースレッドの状態確認

## 5. 成果物テンプレート

### 読解ログ形式
```markdown
## [ファイル名]:[メソッド名]
- **目的**: 
- **引数/戻り値**: 
- **排他制御**: あり/なし (使用箇所)
- **呼び出し先**: 
- **重要な副作用**: 
- **疑問点**: 
```

### フローチャート要素
- 矩形: 処理ステップ
- 菱形: 条件分岐
- 楕円: 開始/終了
- 二重線: 排他制御区間

### 排他制御マップ形式
| メソッド | 保護対象リソース | 理由 | 競合回避する操作 |
|----------|------------------|------|------------------|

## 6. タイムボックス & 優先度再確認

### 各ルートの目安時間
1. **基本的な呼び出しフロー理解** : 1-2時間
   - `<<` → `post` → `ns_execute` の流れ
2. **排他制御ポイント特定** : 1-2時間  
   - `synchronize` 使用箇所とその理由
3. **ワーカースレッド動作理解** : 2-3時間
   - Worker内部クラスの詳細動作
4. **実験・検証** : 1-2時間
   - デバッグコードでの動作確認

### 切り上げ基準
- **最低限達成目標**: `<<` メソッドからタスク実行までの基本フローを説明できる
- **理想目標**: 排他制御の必要性とタイミングを具体的に説明できる
- **スコープ調整**: 時間不足の場合はエラーハンドリングや詳細な状態管理は後回し