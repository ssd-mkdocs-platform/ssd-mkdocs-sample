---
name: starting-issues
description: Issue作業を開始し、ブランチを作成してPlanモードに入る。Use when the user wants to start working on an issue (Issue対応開始), begin a task (タスク開始), or tackle a GitHub issue (課題着手).
allowed-tools: Bash(gh issue:*), Bash(git checkout:*), Bash(git pull:*), Bash(git branch:*), Bash(git stash:*), AskUserQuestion, EnterPlanMode, WebSearch, WebFetch
---

# Issue作業開始

## Quick start

Issue番号を決定し、ブランチを作成して、EnterPlanModeで実装計画を立てる。

## リポジトリ情報

!`git remote -v`

## 現在のブランチ

!`git branch --show-current`

## Open Issues一覧

!`gh issue list --state open`

## Instructions

### 1. Issue番号の決定

- 引数 `$1` が指定されている場合: Issue #$1 の作業を開始
- 引数がない場合: Open Issues一覧から `AskUserQuestion` で作業するIssueを選択

### 2. Issueの詳細確認

```bash
gh issue view {番号}
```

### 3. ブランチ作成

1. ローカルの変更がある場合は `git stash` で退避
2. `git checkout main && git pull origin main` でmainを最新化
3. `git checkout -b issue-{番号}` で作業ブランチを作成

ブランチ命名規則: `issue-{Issue番号}`（例: `issue-123`）

### 4. Planモード開始

`EnterPlanMode` ツールでPlanモードに入り、Issueの内容を基に実装計画を立てる。
