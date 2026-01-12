# ユーザー環境構築

本ドキュメントでは、ローカル開発環境の構築手順を説明する。

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

## Rulesyncセットアップ

Rulesyncは複数のAI開発ツール向けルール設定を統一管理する。

### インストール

Node.jsパッケージ導入時に自動インストールされる。

確認は以下コマンドで実行する。

```shell
rulesync --version
```

### 初期化

プロジェクト初期化時にRulesyncの設定ファイルが生成される。

以下コマンドで設定を確認可能である。

```shell
npx rulesync generate
```

### 設定ファイル

`rulesync.jsonc` ファイルでAI開発ツール、生成機能、その他オプションを指定する。

現在の設定：

- **対象ツール**：Google Antigravity、GitHub Copilot、Claude Code、Codex CLI
- **生成機能**：ルール、無視ファイル、MCP設定

詳細は [Rulesync ドキュメント](https://github.com/dyoshikawa/rulesync) を参照すること。
