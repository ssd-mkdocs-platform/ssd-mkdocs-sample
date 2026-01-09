---
title: テキスト校正
---

# テキスト校正

このリポジトリーでは、textlintの設定と依存関係を単一の基点に集約し、VS Code・CLI・CIの3経路で同一ルールの校正を実現している。

## アーキテクチャーの要点

- ルールの単一ソース化（`.textlintrc.json`）
- 除外対象の一元管理（`.textlintignore`）
- 依存関係の固定（`package.json`と`pnpm-lock.yaml`）
- 実行経路の分離とルール共通化

## 共通ルールの中核

textlint本体と各種ルールセットは`package.json`に集約し、実行時は`.textlintrc.json`を必ず読み込む設計である。これにより、エディター内とCLI/CIでの差分を作らない。

```text
ルール定義: .textlintrc.json
除外設定: .textlintignore
依存固定: package.json + pnpm-lock.yaml
```

## 利用シーン別の実行経路

### 1. VS Codeのリアルタイム校正

VS Code拡張は`.vscode/settings.json`で`.textlintrc.json`を明示参照している。入力時（`onType`）にtextlintが走り、ルールはローカルの`node_modules`と設定ファイルから解決される。

- 設定参照の明示（`textlint.configPath: ".textlintrc.json"`）
- 実行タイミングの統一（`textlint.run: "onType"`）
- 自動修正の無効化（`textlint.autoFixOnSave: false`）

### 2. CLIによるローカル全文書の校正

`pnpm run lint:text`がtextlintを起動し、`"**/*.md"`を対象に校正する。CLIも`.textlintrc.json`と`.textlintignore`を同じく参照するため、VS Codeと同一ルールで検出される。自動修正を適用する場合は`pnpm run lint:text:fix`を使う。

```bash
pnpm run lint:text      # 校正のみ
pnpm run lint:text:fix  # 自動修正を適用
```

### 3. CI（GitHub Actions）による校正

`.github/workflows/textlint.yml`がPR/Push時にtextlintを実行する。`pnpm install --frozen-lockfile`で依存を固定し、`pnpm run lint:text`でローカルと同一コマンドを実行するため、CIでも同じルールが保証される。

```bash
pnpm install --frozen-lockfile
pnpm run lint:text
```

## 同一ルールを維持する設計

3つの経路はいずれも`.textlintrc.json`を参照し、依存は`pnpm-lock.yaml`で固定される。変更点を一か所に集約することで、エディター・CLI・CIの結果が一致する構成になっている。
