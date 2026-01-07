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

- Python 3.13
- uv（Pythonパッケージマネージャー）
- Node.js
- pnpm（Node.jsパッケージマネージャー）

## 環境構築

### Node.jsパッケージの導入

```shell
pnpm install
```

### Pythonパッケージの導入

```shell
uv sync
```

### GTK+ Runtimeのインストール

GTK+ RuntimeはweasyprintのPDF生成に必要な依存パッケージをインストールする。

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

### 推奨VS Code拡張

- **textlint** (`3w36zj6.textlint`): ワークスペースの`.textlintrc.json`と`node_modules`を参照し、CIと同一ルールでリアルタイム校正を行う。

## 日常の利用方法

```powershell
# ローカルプレビュー（http://127.0.0.1:8000 でライブリロード）
uv run mkdocs serve

# 本番ビルド
uv run mkdocs build

# PDF生成（GTK Runtimeが必要）
$env:MKDOCS_PDF=1; uv run mkdocs build

# ドキュメント品質チェック（textlint）
pnpm run lint:text

# ドキュメント品質チェック（自動修正）
pnpm run lint:text:fix
```
