---
allowed-tools: Bash(gh issue:*), Bash(git checkout:*), Bash(git pull:*), Bash(git branch:*), Bash(git stash:*), AskUserQuestion, EnterPlanMode, WebSearch, WebFetch
description: Issue作業を開始（ブランチ作成→Planモード）
argument-hint: [issue-number]
---

# Issue作業開始コマンド

このコマンドはIssue作業を開始するためのワークフローを実行します。

## リポジトリ情報

!`git remote -v`

## 現在のブランチ

!`git branch --show-current`

## Open Issues一覧

!`gh issue list --state open`

## タスク

以下の手順でIssue作業を開始してください：

### 1. Issue番号の決定

- 引数 `$1` が指定されている場合: Issue #$1 の作業を開始
- 引数がない場合: 上記のOpen Issues一覧から `AskUserQuestion` ツールを使って作業するIssueを選択させてください

### 2. Issueの詳細確認

選択されたIssue番号で `gh issue view {番号}` を実行し、Issueの内容を確認してください。

### 3. ブランチ作成

以下の手順でブランチを作成してください：

1. ローカルの変更がある場合は `git stash` で退避
2. `git checkout main && git pull origin main` でmainブランチを最新化
3. `git checkout -b issue-{番号}` で作業ブランチを作成

ブランチ命名規則: `issue-{Issue番号}`（例: `issue-123`）

### 4. Planモード開始

`EnterPlanMode` ツールを使用してPlanモードに入り、Issueの内容を基に実装計画を立ててください。
