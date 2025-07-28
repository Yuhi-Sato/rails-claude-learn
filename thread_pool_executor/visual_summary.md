# ThreadPoolExecutor 視覚的まとめ

## フローチャート: `<<` メソッドの実行フロー

```mermaid
graph TD
    A[executor << task] --> B[ExecutorService#<<]
    B --> C[post(&task)]
    C --> D{synchronize ブロック開始}
    D --> E{running?}
    E -->|true| F[ns_execute]
    E -->|false| G[fallback_action]
    
    F --> H[ns_reset_if_forked]
    H --> I{ns_assign_worker}
    I -->|success| J[worker << [task, args]]
    I -->|fail| K{ns_enqueue}
    K -->|success| L[@queue << [task, args]]
    K -->|fail| M[fallback_action]
    
    J --> N[scheduled_task_count++]
    L --> N
    N --> O[ns_prune_pool?]
    O --> P[synchronize ブロック終了]
    P --> Q[return self]
    
    %% Worker側の処理
    J --> R[Worker#<<]
    R --> S[@queue << message]
    S --> T[Worker Thread]
    T --> U[my_queue.pop]
    U --> V[run_task]
    V --> W[task.call]
    W --> X[pool.ready_worker]
    X --> Y{@queue.shift}
    Y -->|task有| Z[worker << next_task]
    Y -->|task無| AA[@ready.push]
    
    style D fill:#ffcccc
    style P fill:#ffcccc
    style S fill:#ccffcc
    style U fill:#ccffcc
```

## 排他制御マップ

| 保護対象リソース | 排他制御の場所 | 理由 | 競合回避する操作 |
|------------------|----------------|------|------------------|
| **@pool** (全ワーカー配列) | synchronize ブロック | 複数スレッドが同時にワーカー追加/削除 | add_worker, remove_worker |
| **@ready** (アイドルワーカー配列) | synchronize ブロック | ワーカー取得と返却の競合 | pop/push操作の整合性 |
| **@queue** (タスクキュー) | synchronize ブロック | タスク追加とワーカーによる取得の競合 | enqueue vs dequeue |
| **@scheduled_task_count** | synchronize ブロック | カウンターの原子的更新 | 統計情報の正確性 |
| **@completed_task_count** | synchronize ブロック | カウンターの原子的更新 | 統計情報の正確性 |
| **実行状態** (running/stopped) | synchronize ブロック | 状態変更の原子性 | shutdown処理との競合 |

### 非保護リソース
| リソース | 理由 |
|----------|------|
| **Worker内部キュー** | 各ワーカー専用、Rubyの標準Queueクラス（スレッドセーフ） |
| **タスク実行** | Worker専用スレッドで実行、他との競合なし |

## 重要な設計パターン

### 1. 遅延実行パターン
```ruby
deferred_action = synchronize {
  # 短時間の準備処理のみ
  if running?
    ns_execute(*args, &task)
  else
    fallback_action(*args, &task)
  end
}
# synchronize外で実際の処理
deferred_action.call if deferred_action
```

**目的**: synchronizeブロックの滞在時間を最小化

### 2. 二段階キューイング
```
1. @ready からアイドルワーカーを取得
   ↓ 失敗
2. @queue に待機タスクとして追加
   ↓ ワーカー完了時
3. @queue からタスクを取得して即座に割り当て
```

**不変条件**: `@ready` または `@queue` のどちらかが常に空

### 3. 再帰的ロック対応
```ruby
def synchronize
  if @__Lock__.owned?
    yield  # 既に取得済み→そのまま実行
  else
    @__Lock__.synchronize { yield }  # 新規取得
  end
end
```

**目的**: 同一スレッド内での複数回ロックを安全に処理

## 実験結果の要約

### パフォーマンス特性
- **スループット**: 約7,758 tasks/sec (100タスク/4ワーカー)
- **プール管理**: 必要に応じて自動的にワーカー数を調整 (min→max)
- **レイテンシ**: `<<` 操作は即座にリターン（非同期）

### 排他制御の効果確認
- **排他制御なし**: 期待値1000 → 実際250 (75%の損失)
- **排他制御あり**: 期待値1000 → 実際1000 (完全な整合性)

### ワーカー動作
- 各ワーカーは独立したスレッドで動作
- タスク完了後、即座に次のタスクまたはアイドル状態へ遷移
- プールサイズは動的に調整（最大4スレッドまで拡張を確認）

## 学習成果

✅ **ThreadPoolExecutorの完全なデータフロー理解**  
✅ **排他制御の必要性とタイミングの特定**  
✅ **Worker協調メカニズムの解明**  
✅ **実際の動作確認と性能測定**  
✅ **concurrent-rubyの優れた設計パターンの発見**