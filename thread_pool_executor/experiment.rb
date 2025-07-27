#!/usr/bin/env ruby
# ThreadPoolExecutor の << メソッドと排他制御の実験コード

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
  max_queue: 10
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

# パフォーマンステスト
puts "## 3. パフォーマンステスト（1000タスク）"
task_count = 1000
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

# キューオーバーフロー実験
puts "## 4. キューオーバーフロー実験"
small_executor = Concurrent::ThreadPoolExecutor.new(
  min_threads: 1,
  max_threads: 1,
  max_queue: 2,
  fallback_policy: :discard
)

puts "制限付きエグゼキューター（max_queue: 2）"
puts "長時間タスクでキューを埋める..."

# ワーカーをブロック
small_executor << proc { sleep(1) }
sleep(0.1)

# キューを埋める
3.times do |i|
  small_executor << proc do
    puts "  キュータスク#{i} 実行"
  end
end

# オーバーフロータスクの投入
puts "オーバーフロータスクを投入..."
overflow_result = small_executor << proc do
  puts "  オーバーフロータスク実行（この行は表示されないはず）"
end

puts "オーバーフロータスクの戻り値: #{overflow_result.class}"
puts "キュー長: #{small_executor.queue_length}"
puts "remaining_capacity: #{small_executor.remaining_capacity}"

sleep(1.5)
puts "実行完了後:"
puts "  完了タスク数: #{small_executor.completed_task_count}"

# 実験終了
puts
puts "## 実験終了 - エグゼキューターをシャットダウン"
executor.shutdown
small_executor.shutdown

executor.wait_for_termination(5)
small_executor.wait_for_termination(5)

puts "シャットダウン完了"