/learnreq
---
allowed-tools: TodoWrite, TodoRead, Read, Write, MultiEdit, Bash(mkdir:*)
description: Define learning objectives, unknowns, and verification methods before reading code
---

## Context
- Learning target description: $ARGUMENTS   # 学習したいテーマ/疑問/背景

## Your task

### 1. Create directory
- Create `.learn` directory if it doesn't exist
- Think the directory name abount the learning target and create the directory in `.learn` directory. We call the directory name as `<directory_name>`

### 2. Analyze the learner's request
抽出・整理すべき項目:
- 学習目的（何を理解/獲得したいのか）
- 既知/未知（前提知識・分からない点）
- 仮説（こうなっているはず、という当て）
- 優先度（どれから理解するか）
- 検証方法（どうやって理解できたと判断するか／コード上で何を見るか）
- 期待するアウトプット（ノート、図、サンプルコード等）

### 3. Create Learning Requirements Doc
`.learn/<directory_name>/learning_requirements.md` を作成し、以下の章立てで記述:

# 学習要件定義書 - [テーマ名]

## 1. 学習目的
- [最終的に身につけたい理解/スキル]

## 2. 既知と未知
### 2.1 既知
- [既に分かっていること/仮説]

### 2.2 未知・疑問点
- [まだ分からないこと/不安な点]

## 3. 仮説と検証方針
| 疑問/仮説 | どのコード/資料で確認する？ | 検証方法 | 完了基準 |
|-----------|------------------------------|----------|----------|
|           |                              |          |          |

## 4. 優先度と学習順序
1. [最優先トピック]
2. [次点トピック]
...

## 5. 期待アウトプット・定着方法
- [理解を示す成果物（図、記事、発表資料、PRなど）]

## 6. リスク/詰まりポイントと回避策
- [想定される沼ポイント] : [抜け道/代替手段]

## 4. Create TODO entry
TodoWrite: 「学習要件定義の作成とレビュー」を登録

## 5. Present to user
作成した learning_requirements.md を提示し、

- 目的/未知の網羅性の確認

- 優先度の妥当性

- 検証方法・完了基準の明確さ
を尋ねる

think hard
