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
- uv（Pythonパッケージマネージャー）
- [Node.js](https://nodejs.org/)
- [pnpm](https://pnpm.io/ja/installation)
- [ni](https://github.com/antfu-collective/ni)

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
uv sync
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
uv run mkdocs serve
```

### Pull Request作成前チェック

文書のリンク切れや、ドキュメント品質をチェックする。

```shell
# 本番ビルド
uv run mkdocs build

# ドキュメント品質チェック（textlint）
pnpm run lint:text

# ドキュメント品質チェック（自動修正）
pnpm run lint:text:fix
```

### PDF生成

#### Windows

```powershell
$env:MKDOCS_PDF=1; uv run mkdocs build
```

#### Linux & macOS

```bash
MKDOCS_PDF=1 uv run mkdocs build
```
