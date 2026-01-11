# 利用方法

本ドキュメントでは、ドキュメント基盤の日常的な利用方法を説明する。

## 文書記述

MkDocsを起動してプレビューを確認しながら文書を記述する。

```shell
# ローカルプレビュー（http://127.0.0.1:8000）
pnpm run mkdocs
```

## Pull Request作成前チェック

文書のリンク切れや、ドキュメント品質をチェックする。

```shell
# 簡易ビルド（PRプレビュー相当）
pnpm run mkdocs:build

# 本番Web用ビルド（MermaidのSVG化を含む）
pnpm run mkdocs:build:svg

# ドキュメント品質チェック（textlint）
pnpm run lint:text

# ドキュメント品質チェック（自動修正）
pnpm run lint:text:fix
```

## PDF生成

正式公開版と同様に、Mermaid を PNG に変換して PDF を生成する。

### Windows

```shell
pnpm run mkdocs:pdf
```

## 実行コマンドの補足

MkDocsや環境同期は `pnpm` のスクリプトから実行する。内部では `uv` を呼び出すファサードになっているため、`pnpm` から統一的に操作できる。
