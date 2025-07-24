/learnplan
---
allowed-tools: TodoWrite, TodoRead, Read, Write, MultiEdit
description: Plan how to explore the codebase to satisfy the learning requirements
---

## Context
- Learning requirements: @.learn/<directory_name>/learning_requirements.md

## Your task
1. Verify prerequisites
`.learn/<directory_name>/learning_requirements.md` が存在するか確認

なければ /learnreq の実行を促す

2. Analyze requirements
未知/仮説/検証方針を読み、どのコード領域に当たるべきか決める

3. Create Reading Plan Document
`.learn/<directory_name>/reading_plan.md` を以下で作成:

# 読解計画書 - [テーマ名]

## 1. 対象コードベースの俯瞰
- リポジトリ/ディレクトリ構成の概要
- 主要エントリポイント（実行開始箇所/主要クラス）
- 重要モジュール・依存関係

## 2. 読解ルートマップ
### 2.1 優先ルート（必ず読む）
1. [ファイル/クラス] : 読む理由 / 関連する仮説
2. ...

### 2.2 補助ルート（必要に応じて）
- [ファイル/クラス] : どの疑問を補完するか

## 3. トレース方針
- 呼び出し追跡方法（grep, ctags, ripgrep, IDE機能 など）
- ログ/デバッガ/テストで確認したいポイント

## 4. 実験計画 (必要なら)
- どのテストや小実験を行うか
- 必要な準備（環境構築、データ投入など）

## 5. 成果物テンプレート
- 読解ログの書式
- 図/メモ/要約の形式

## 6. タイムボックス & 優先度再確認
- 各ルートの目安時間
- 切り上げ基準・スコープ調整基準
4. Update TODO
TodoWrite: 「読解計画の作成とレビュー」を登録

5. Present to user
読解計画を提示し、探索順序/範囲/実験方針の確認を求める

think hard
