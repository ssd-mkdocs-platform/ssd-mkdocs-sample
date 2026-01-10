# 仕様駆動開発時代のドキュメント基盤

MkDocs + Material for MkDocsを使用したドキュメント基盤である。Mermaidによる図表作成、WeasyPrintによるPDF生成をサポートしている。

## 技術スタック

| 技術 | 用途 |
|------|------|
| MkDocs + Material for MkDocs | 静的サイトジェネレーター |
| Mermaid | Markdown内での図表作成 |
| Draw.io | SVG図表作成 |
| Playwright | Mermaidレンダリング用ブラウザ自動化 |
| WeasyPrint | PDF生成 |
| textlint | ドキュメント品質チェック |

## システム要件

事前に以下のソフトウェアが利用可能な状態にしておくこと。

- Python 3.13+
- uv 0.9.17+
- Node.js 24.12.0+
- pnpm 10.27.0+

## 環境構築

### GTK+ Runtimeのインストール

weasyprintのPDF生成に必要なGTK+ Runtimeをインストールする。ローカルでPDFをビルドしないなら不要。

#### Windows

```pwsh
winget install --id tschoonj.GTKForWindows
```

#### Linux

```bash
sudo apt-get update
sudo apt-get install -y libpango-1.0-0 libpangoft2-1.0-0 libpangocairo-1.0-0 libcairo2 libgdk-pixbuf-2.0-0 libffi-dev fonts-noto-cjk fonts-noto-cjk-extra
```
#### macOS

```bash
brew install python pango libffi
```

### Node.js & Pythonパッケージの導入

```shell
pnpm install
pnpm run python:sync
```

### VS Code拡張

CIと同一ルールでリアルタイム校正を行う。

```shell
code --install-extension 3w36zj6.textlint
```

## 利用方法

### 文書記述

MkDocsを起動してプレビューを確認しながら文書を記述する。

```shell
# ローカルプレビュー（http://127.0.0.1:8000）
pnpm run mkdocs
```

### Pull Request作成前チェック

文書のリンク切れや、ドキュメント品質をチェックする。

```shell
# 本番ビルド
pnpm run mkdocs:build

# ドキュメント品質チェック（textlint）
pnpm run lint:text

# ドキュメント品質チェック（自動修正）
pnpm run lint:text:fix
```

### PDF生成

#### Windows

```shell
pnpm run mkdocs:pdf
```

## 実行コマンドの補足

MkDocsや環境同期は `pnpm` のスクリプトから実行する。内部では `uv` を呼び出すファサードになっているため、`pnpm` から統一的に操作できる。
