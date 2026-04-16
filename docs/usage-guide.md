# 利用方法

本ドキュメントでは、ドキュメント基盤の日常的な利用方法を説明する。

## 文書記述

MkDocsを起動してプレビューを確認しながら文書を記述する。

```shell
# ローカルプレビュー（http://127.0.0.1:8000）
mise run mkdocs
```

## Pull Request作成前チェック

文書のリンク切れや、ドキュメント品質をチェックする。

```shell
# 簡易ビルド（PRプレビュー相当）
mise run mkdocs:build

# 本番Web用ビルド（MermaidのSVG化を含む）
mise run mkdocs:build:svg

# ドキュメント品質チェック（textlint）
mise run lint:text

# ドキュメント品質チェック（自動修正）
mise run lint:text:fix
```

## PDF生成

正式公開版と同様に、Mermaid を PNG に変換して PDF を生成する。

### Windows

```shell
mise run mkdocs:pdf
```

## 実行コマンドの補足

普段の実行入口は `mise run` に統一する。内部では `pnpm` と `uv` を利用しているため、既存の `package.json` スクリプトもそのまま利用できる。

`infra/scripts` 配下の PowerShell スクリプトも `mise task` として実行できる。

```shell
mise run infra:test
mise run infra:build-image -- -ImageTag v1.0.0
mise run infra:deploy-handson-env -- -UserCount 20
mise run infra:remove-handson-env -- -All
```
