#!/usr/bin/env ruby
# ThreadPoolExecutor の << メソッドと排他制御の実験コード（修正版）

require 'concurrent-ruby'
require 'benchmark'

puts "=== ThreadPoolExecutor実験 ==="
puts "Ruby実装: #{RUBY_ENGINE} #{RUBY_VERSION}"
puts

# 基本的な動作確認
puts "## 1. 基本的な動作確認"
executor = Concurrent::ThreadPoolExecutor.new(
  min_threads: 2,
  max_threads: 4,
  max_queue: 0  # 無制限キュー
)

puts "初期状態:"
puts "  プールサイズ: #{executor.length}"
puts "  アクティブ数: #{executor.active_count}"
puts "  キュー長: #{executor.queue_length}"
puts

# 単一タスクの実行
puts "タスク実行:"
executor << proc do
  puts "  [#{Thread.current.object_id}] タスク実行中"
  sleep(0.1)
  puts "  [#{Thread.current.object_id}] タスク完了"
end

sleep(0.2)
puts "実行後:"
puts "  プールサイズ: #{executor.length}"
puts "  完了タスク数: #{executor.completed_task_count}"
puts

# 複数タスクの並行実行
puts "## 2. 複数タスクの並行実行"
start_time = Time.now

5.times do |i|
  executor << proc do
    thread_id = Thread.current.object_id
    puts "  [#{thread_id}] タスク#{i} 開始"
    sleep(0.1)
    puts "  [#{thread_id}] タスク#{i} 完了"
  end
end

sleep(0.3)
puts "5タスク実行後:"
puts "  プールサイズ: #{executor.length}"
puts "  完了タスク数: #{executor.completed_task_count}"
puts "  実行時間: #{(Time.now - start_time).round(3)}秒"
puts

# パフォーマンステスト（タスク数を減らす）
puts "## 3. パフォーマンステスト（100タスク）"
task_count = 100
completed = 0
mutex = Mutex.new

start_time = Time.now
benchmark_time = Benchmark.realtime do
  task_count.times do |i|
    executor << proc do
      # 軽い計算処理
      result = (1..100).sum
      mutex.synchronize { completed += 1 }
    end
  end
  
  # 全タスクの完了を待機
  while completed < task_count
    sleep(0.01)
  end
end

puts "結果:"
puts "  実行タスク数: #{task_count}"
puts "  完了タスク数: #{completed}"
puts "  実行時間: #{benchmark_time.round(3)}秒"
puts "  スループット: #{(task_count / benchmark_time).round(1)} tasks/sec"
puts "  最大プールサイズ: #{executor.largest_length}"
puts

# 排他制御の確認
puts "## 4. 排他制御の確認"
shared_counter = 0
iterations = 1000

puts "共有カウンターを#{iterations}回インクリメント（排他制御なし）"
unsafe_executor = Concurrent::ThreadPoolExecutor.new(min_threads: 4, max_threads: 4)

start_time = Time.now
iterations.times do
  unsafe_executor << proc do
    # 危険：排他制御なしでの共有変数操作
    temp = shared_counter
    sleep(0.0001)  # 意図的に競合状態を作る
    shared_counter = temp + 1
  end
end

sleep(1)
puts "結果（期待値: #{iterations}, 実際の値: #{shared_counter}）"
puts "データ競合により値が不正確になる可能性があります"
puts

# 安全な排他制御版
puts "同じ処理を排他制御ありで実行:"
safe_counter = 0
safe_mutex = Mutex.new

iterations.times do
  unsafe_executor << proc do
    safe_mutex.synchronize do
      temp = safe_counter
      sleep(0.0001)
      safe_counter = temp + 1
    end
  end
end

sleep(1)
puts "結果（期待値: #{iterations}, 実際の値: #{safe_counter}）"
puts "排他制御により正確な値が保証されます"
puts

# 実験終了
puts "## 実験終了 - エグゼキューターをシャットダウン"
executor.shutdown
unsafe_executor.shutdown

executor.wait_for_termination(5)
unsafe_executor.wait_for_termination(5)

puts "シャットダウン完了"