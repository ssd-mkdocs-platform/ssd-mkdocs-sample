---
name: creating-issues
description: 対話形式でGitHub Issueを作成する。Use when the user wants to create an issue (Issue作成), report a bug (バグ報告), request a feature (機能追加), or improve documentation (ドキュメント改善).
allowed-tools: Bash(git remote:*), Bash(gh issue create:*), AskUserQuestion, Skill
---

# GitHub Issue作成

## Quick start

AskUserQuestionツールでIssueタイプを確認し、必要な情報を収集してから `gh issue create` で作成する。

## リポジトリ情報

!`git remote -v`

## Instructions

### 1. Issueタイプの確認

AskUserQuestionツールで以下の質問をする：

**質問**: どのタイプのIssueを作成しますか？
- **bug**: バグ報告（不具合、エラー、予期しない動作）
- **enhancement**: 機能追加・改善（新機能、既存機能の改善）
- **documentation**: ドキュメント関連（誤字脱字、説明不足、新規ドキュメント）
- **question**: 質問・相談（使い方、設計相談）

### 2. タイプ別の情報収集

選択されたタイプに応じて、AskUserQuestionで必要な情報を収集：

#### bug
- タイトル、再現手順、期待される動作、実際の動作、環境情報（任意）

#### enhancement
- タイトル、目的・背景、提案する解決策、代替案（任意）

#### documentation
- タイトル、対象ページ/セクション、現状の問題点、改善案

#### question
- タイトル、質問の詳細、背景・コンテキスト

### 3. Issue作成

収集した情報からMarkdown形式の本文を生成し、以下を実行：

```bash
gh issue create --title "タイトル" --body "本文" --label "タイプ"
```

### 4. 結果確認

作成されたIssueのURLを表示。

### 5. 次のアクション確認

AskUserQuestionで「続けてこのIssueの作業を開始しますか？」と確認：
- **はい**: `Skill` ツールで `starting-issues` を呼び出す（引数に作成したIssue番号を渡す）
- **いいえ**: 終了
