---
allowed-tools: Bash(git remote:*), Bash(gh issue create:*), AskUserQuestion
description: 対話形式でGitHub Issueを作成
---

# Issue作成

## リポジトリ情報

!`git remote -v`

## タスク

以下の手順でGitHub Issueを作成してください：

### 1. Issueタイプの確認

AskUserQuestionツールで以下の質問をしてください：

**質問**: どのタイプのIssueを作成しますか？
- **bug**: バグ報告（不具合、エラー、予期しない動作）
- **enhancement**: 機能追加・改善（新機能、既存機能の改善）
- **documentation**: ドキュメント関連（誤字脱字、説明不足、新規ドキュメント）
- **question**: 質問・相談（使い方、設計相談）

### 2. タイプ別の情報収集

選択されたタイプに応じて、AskUserQuestionで必要な情報を収集してください：

#### bug の場合
- タイトル（簡潔に問題を説明）
- 再現手順
- 期待される動作
- 実際の動作
- 環境情報（任意）

#### enhancement の場合
- タイトル（提案内容を簡潔に）
- 目的・背景（なぜこの機能が必要か）
- 提案する解決策
- 代替案（任意）

#### documentation の場合
- タイトル（対象と問題を簡潔に）
- 対象ページ/セクション
- 現状の問題点
- 改善案

#### question の場合
- タイトル（質問を簡潔に）
- 質問の詳細
- 背景・コンテキスト

### 3. Issue本文の生成

収集した情報を元に、Markdown形式のIssue本文を生成してください。

### 4. Issueの作成

以下のコマンドでIssueを作成：
```bash
gh issue create --title "タイトル" --body "本文" --label "タイプ"
```

### 5. 結果の確認

作成されたIssueのURLを表示してください。
