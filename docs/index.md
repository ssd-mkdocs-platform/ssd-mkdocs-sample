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

ハンズオン配布や、ローカルに開発ツールを入れたくない場合に使う。`settings.local.json`で起動先となるコンテナイメージを指定する。

### 1.設定ファイルの準備

`settings.template.json`を `settings.local.json`にコピーして、自分の環境に合わせて各項目を書き換える。

```json
{
  "subscriptionId": "<your-subscription-id>",
  "tenantId": "<your-tenant-id>",
  "location": "japaneast",
  "resourceGroup": "rg-genai-mkdocs-sample-hands-on",
  "ghcrImage": "ghcr.io/genai-docs/handson-env"
}
```

| 項目 | 用途 | 必須となる操作 |
|------|------|----------------|
| `subscriptionId` | Azureサブスクリプション ID | Azureへのデプロイ／撤去／状態取得 |
| `tenantId` | Azureテナント ID。GitHub Actionsのフェデレーション認証などで参照する | Azure連携セットアップ |
| `location` | Azureリソースを展開するリージョン（例: `japaneast`） | Azureへのデプロイ |
| `resourceGroup` | ハンズオン用リソースグループ名のプレフィックス。デプロイ時は末尾にタイムスタンプが付く | Azureへのデプロイ／撤去／状態取得 |
| `ghcrImage` | code-serverコンテナイメージの参照名（タグを除く） | `build-image` / `run-local` / `run-remote`、Azureデプロイすべて |

ローカルでイメージをビルドして起動するだけなら、実質的に必須なのは`ghcrImage`のみで、他のAzure系項目はダミーでも構わない。

### 2.イメージのビルドと起動

ローカルでビルドしてから起動する場合。

```bash
mise run build-image   # infra/docker/Dockerfile を :latest でビルド
mise run run-local     # http://localhost:8080 で code-server 起動
```

GitHub Container Registryに公開済みのイメージを使う場合。

```bash
mise run run-remote    # settings.local.json の ghcrImage を pull して起動
```

ブラウザで `http://localhost:8080` を開き、既定パスワード `changeme` でログインする（`-Password` で変更可能）。

Azure上に共有ハンズオン環境を展開する手順は[実行環境](実行環境/index.md)にまとめている。

## 詳しくは

- [ユーザーガイド](usage-guide.md)
- [実行環境の概要](実行環境/index.md)
- [アーキテクチャー](アーキテクチャー/index.md)
- [サンプル一覧](サンプル/index.md)
