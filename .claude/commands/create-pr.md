---
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(gh pr create:*)
description: mainブランチからの差分を分析してPRを作成
---

# PR作成

以下の情報を元にプルリクエストを作成してください。

## 現在のブランチ

!`git branch --show-current`

## mainブランチからの差分

!`git diff main`

## mainブランチからのコミット履歴

!`git log main..HEAD --oneline`

## タスク

上記の情報を分析して、以下を実行してください：

1. **PRタイトルと本文を生成**
   - タイトル: 変更内容を簡潔に要約（日本語、80文字以内）
   - 本文: 以下のセクションを含める
     - ## 概要: 変更の目的と背景
     - ## 変更内容: 主な変更点を箇条書き
     - ## テスト: テスト方法や確認項目（該当する場合）

2. **Issue番号の確認**
   - 現在のブランチ名に `issue` という単語と番号が含まれているか確認
   - パターン例: `issue-123`, `issue/456`, `fix-issue-789`
   - 見つかった場合、PR本文の末尾に `Closes #番号` を追加

3. **PRの作成**
   - `gh pr create --title "タイトル" --body "本文" --base main` を実行
   - Issue番号がある場合は本文末尾に `Closes #番号` を含める

4. **結果の確認**
   - 作成されたPRのURLを表示
