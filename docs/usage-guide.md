# ユーザーガイド

本ドキュメントでは、ドキュメント基盤の日常的な利用方法を説明する。コマンドは `package.json` の `scripts` を [`@antfu/ni`](https://github.com/antfu/ni) の `nr` でラップして実行する前提で記述する。

## ni / nr とは

`@antfu/ni` は、リポジトリのロックファイル（`pnpm-lock.yaml` / `package-lock.json` / `yarn.lock`）から実パッケージマネージャーを自動判別して委譲するユーティリティである。本リポジトリではpnpmが検出されるため、`nr <script>` は `pnpm run <script>` と等価になる。

| エイリアス | 役割 | 本リポジトリでの実体 |
|-----------|------|-----------------------|
| `ni` | 依存関係のインストール | `pnpm install` |
| `nr` | `package.json` の script 実行 | `pnpm run <script>` |
| `nlx` | ワンショット実行 | `pnpm dlx <pkg>` |

通常は `mise run setup` で依存関係の導入は完了するため、個別の `ni` は不要である。

## 文書記述

MkDocsを起動し、ライブリロードのプレビューで内容を確認しながらMarkdownを書く。

```shell
nr mkdocs            # http://127.0.0.1:8000 でライブプレビュー
```

## Pull Request 作成前チェック

レビュー前に本番相当のビルドと品質チェックを通しておく。

```shell
nr mkdocs:build      # Mermaid の SVG/PNG 変換と PDF 出力を含む本番相当ビルド
nr lint:text         # textlint（表記ゆれ・用字用語などのチェック）
nr lint:text:fix     # textlint 自動修正（機械的に直せるものだけ）
```

`mkdocs:build` は `RENDER_SVG=1 RENDER_PNG=1 ENABLE_PDF=1` を有効にした上で `uv run mkdocs build` を実行する。PDFは `site/pdf/ドキュメンテーション戦略.pdf` に出力される。

## スライド作成

MarpスライドのプレビューとPDF生成は次のとおり。

```shell
nr marp              # 変更監視つきプレビュー（docs/スライド）
nr marp:build        # docs/スライド/dist に PDF を出力
```

## 実行コマンドの整理

本リポジトリのコマンドは2系統に分かれており、役割で使い分ける。

| 系統 | 呼び出し方 | 用途 |
|------|------------|------|
| `package.json` scripts | `nr <script>` | ドキュメントのプレビュー／ビルド／品質チェック／スライド |
| `mise.toml` tasks | `mise run <task>` | 環境構築、コンテナイメージのビルド／起動、ハンズオン環境の Azure デプロイ、テスト |

両者は機能的に重複しておらず、用途ごとに排他的に定義されている。たとえばインフラ系は `mise run` 側で管理する。

```shell
mise run test                                   # Pester テスト実行
mise run build-image                            # ハンズオン用コンテナイメージをローカルビルド
mise run deploy-handson-env -- -UserCount 20    # Azure にハンズオン環境をデプロイ
mise run remove-handson-env -- -All             # ハンズオン環境を撤去
```
