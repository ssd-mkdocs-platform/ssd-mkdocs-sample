---
name: issue-starter
description: Issue作業を開始するためのワークフロー。worktree上でIssue番号を特定し、Issueの内容を確認してPlanモードに入る。ユーザーが「/start-issue」を実行したとき、またはIssue作業の開始を依頼されたときに使用する。
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion, EnterPlanMode, WebSearch, WebFetch
---

# Issue作業開始スキル

このスキルはIssue作業を開始するためのワークフローを実行します。

## 前提条件

- 事前にworktreeが作成済みであること
- 現在そのworktree上にいること
- worktreeのディレクトリ名の末尾の数値がIssue番号であること（例: `fix-issue-13` → Issue #13）

## 手順

以下の手順でIssue作業を開始してください：

### 1. Worktree確認

以下のコマンドを実行してworktree上にいるか確認してください：

```bash
git rev-parse --git-dir
git rev-parse --git-common-dir
```

- **値が異なる場合**: worktree上にいます。次のステップへ進んでください。
- **値が同じ場合**: メインリポジトリ上にいます。worktreeを作成してから再度このコマンドを実行するようユーザーに案内してください。

### 2. Issue番号の決定

現在のディレクトリ名の末尾にある数値をIssue番号として抽出してください。

```bash
pwd
```

例:
- `D:\spec-driven-docs-infra-worktrees\fix-issue-13` → Issue #13
- `/home/user/worktrees/feature-issue-42` → Issue #42

### 3. Issueの詳細確認

抽出したIssue番号で以下のコマンドを実行し、Issueの内容を確認してください：

```bash
gh issue view {番号}
```

### 4. Planモード開始

`EnterPlanMode` ツールを使用してPlanモードに入り、Issueの内容を基に実装計画を立ててください。
