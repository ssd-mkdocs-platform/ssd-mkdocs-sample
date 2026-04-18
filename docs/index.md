# 生成AI時代のドキュメント基盤

このリポジトリは、以下の2つをサンプルとして提供する。

- **ドキュメントを記述する基盤**（Markdown + Mermaid + Draw.io + textlint + MkDocs）
- **記述した文書を公開する仕組み**（GitHub Pages / Azure Static Web Apps）

採用している技術の一覧は [技術スタック](tech-stack.md) を参照する。

## 3つの実行環境

用途に応じて、次の3形態でドキュメント執筆環境を利用できる。

| 形態 | 想定用途 | 前提 |
|------|---------|------|
| ローカル（Linux / WSL） | 普段の執筆・プレビュー | `mise`でツールを揃える |
| DevContainer | VS Code で隔離環境を使いたい | Docker + VS Code + Dev Containers拡張 |
| code-server | ブラウザだけでハンズオンしたい | Docker（ローカル）または Azure（配布） |

## ローカル環境（Linux / WSL）

`mise.toml`でPython / uv / Node.js / pnpmのバージョンを固定している。以下の手順でツールを揃える。

### 1.mise のインストール

```bash
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
exec "$SHELL"
```

### 2.依存関係のインストール

Debian / Ubuntu系ではまずWeasyPrintやPlaywrightのネイティブ依存（Chromium、Pango、Cairo、日本語フォントなど）をaptで導入する。`sudo`が必要で、初回のみ実行する。

```bash
mise run setup-system
```

続いてランタイムとPython / Nodeの依存関係をまとめて取得する。

```bash
mise run setup      # mise install / uv sync / Playwright / pnpm install をまとめて実行
```

macOSやWindows、その他のディストリビューションでは `setup-system`は対象外である。該当環境ではネイティブ依存を個別に導入する必要があるため、DevContainerまたはcode-serverの利用を推奨する。

### 3.ドキュメントのプレビュー

```bash
pnpm mkdocs         # http://127.0.0.1:8000 でライブプレビュー
```

## DevContainer

VS Codeの**Dev Containers**拡張を導入し、リポジトリを開いた際に表示される「Reopen in Container」を選ぶと、`.devcontainer/devcontainer.json`が `.devcontainer/Dockerfile`をビルドして起動する。

当DockerfileはGHCRに公開済みの下記ハンズオンイメージをベースにしており、ビルドはベースイメージのpullのみで完了するためホスト側に`mise`やPythonを入れずに同じツール構成で作業できる。

- ghcr.io/genai-docs/handson-env:latest

ポート8000は自動フォワードされ、MkDocsライブプレビューにブラウザでアクセスできる。

## code-server（ブラウザ版 VS Code）

ハンズオン配布や、ローカルに開発ツールを入れたくない場合に使う。実行環境（Docker イメージ定義、起動・ Azure デプロイスクリプト、Bicep、CI）は別リポジトリ [genai-docs/genai-docs-env](https://github.com/genai-docs/genai-docs-env) に切り出している。該当リポジトリで `mise run run-local` / `mise run run-remote` / `mise run deploy-handson-env` を実行する。

当リポジトリの DevContainer は同ハンズオンイメージ `ghcr.io/genai-docs/handson-env:latest` をベースとして使うため、イメージ更新は env リポジトリ側で完結する。

Azure上に共有ハンズオン環境を展開する手順は[実行環境](実行環境/index.md)にまとめている。

## 詳しくは

- [ユーザーガイド](usage-guide.md)
- [実行環境の概要](実行環境/index.md)
- [アーキテクチャー](アーキテクチャー/index.md)
- [サンプル一覧](サンプル/index.md)
