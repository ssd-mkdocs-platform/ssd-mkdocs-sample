---
name: starting-issues
description: Issue作業を開始し、ブランチを作成してPlanモードに入る。Use when the user wants to start working on an issue (Issue対応開始), begin a task (タスク開始), or tackle a GitHub issue (課題着手).
allowed-tools: Bash(gh issue:*), Bash(git checkout:*), Bash(git pull:*), Bash(git branch:*), Bash(git stash:*), Bash(git rev-parse:*), Bash(git show-ref:*), Bash(git worktree:*), Bash(mkdir:*), Bash(cd:*), AskUserQuestion, EnterPlanMode, WebSearch, WebFetch, Skill
---

# Issue作業開始

## Quick start

Issue番号を決定し、worktreeを作成（または既存worktreeに移動）して、EnterPlanModeで実装計画を立てる。

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

### 3. 作業環境の準備

以下の手順でworktreeを作成し、作業ディレクトリへ移動する。

#### 3.1 パスの決定

```bash
# リポジトリルートを取得
repoRoot=$(git rev-parse --show-toplevel)
repoName=$(basename "$repoRoot")
worktreesRoot="$(dirname "$repoRoot")/${repoName}-worktrees"
branchName="fix-issue-{番号}"
worktreePath="${worktreesRoot}/${branchName}"
```

- **worktrees用ディレクトリ**: `[リポジトリ親ディレクトリ]/[リポジトリ名]-worktrees/`
- **worktreeパス**: `[worktrees用ディレクトリ]/fix-issue-{番号}`
- **ブランチ名**: `fix-issue-{番号}`

#### 3.2 既存worktreeの確認

`git worktree list` で対象のworktreeが既に存在するか確認。
- **存在する場合**: そのディレクトリへ移動して次のステップへ
- **存在しない場合**: 3.3へ進む

#### 3.3 worktreeの作成

1. worktrees用ディレクトリが存在しない場合は作成:
   ```bash
   mkdir -p "${worktreesRoot}"
   ```

2. ブランチの存在確認:
   ```bash
   # ローカルブランチの確認
   git show-ref --verify --quiet "refs/heads/${branchName}"

   # リモートブランチの確認（ローカルがない場合）
   git show-ref --verify --quiet "refs/remotes/origin/${branchName}"
   ```

3. worktreeの作成:
   - **ローカルブランチがある場合**:
     ```bash
     git worktree add "${worktreePath}" "${branchName}"
     ```
   - **ローカルブランチがない場合**:
     - リモートブランチがあれば起点として使用、なければHEADを起点に
     ```bash
     git worktree add -b "${branchName}" "${worktreePath}" "${startPoint}"
     ```

#### 3.4 作業ディレクトリへ移動

```bash
cd "${worktreePath}"
```

### 4. Planモード開始

`EnterPlanMode` ツールでPlanモードに入り、Issueの内容を基に実装計画を立てる。

### 5. 次のアクション確認（実装完了後）

実装が完了したら、AskUserQuestionで「PRを作成しますか？」と確認：
- **はい**: `Skill` ツールで `creating-prs` を呼び出す
- **いいえ**: 終了
