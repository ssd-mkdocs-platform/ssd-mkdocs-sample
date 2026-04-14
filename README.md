# 生成AI時代のドキュメント基盤

生成AI時代におけるドキュメント基盤テンプレート。

- デモサイト
    - [GitHub Pages](https://genai-docs.github.io/genai-mkdocs-sample/)
    - [Azure Static Web Apps](https://white-stone-0b8d2c100.4.azurestaticapps.net/)

特徴：

1. ヒューマン & AIフレンドリー
2. ポータブル

人が書きやすく読みやすいドキュメントで、AIによる生成・レビュー・活用が容易で、かつPDF形式での配布も可能なドキュメント基盤を提供する。

具体的には以下の要素を備えている：

- Markdownによる文書記述
- Mermaidによる図表作成
- Draw.ioによるSVG図表作成
- textlintによる品質チェック・フィックス
- ハイブリッド公開戦略：
    - **GitHub Pages**： 正式文書の公開用。GitHub Enterprise のリポジトリ権限により、社内の非開発者を含む広範なユーザー（人数制限なし）への認証付き公開を実現（非Enterpriseの場合はSWAの無料プランで代替可能）
    - **Azure Static Web Apps (SWA)**： 開発・プレビュー用。Pull Request 時にプレビュー環境を自動生成。GitHub ActionsによるGitHubとSWAの権限の自動同期を提供（オプション）
- 静的サイト全体を1つのPDFにまとめて配布可能

## 開発環境のセットアップ

### DevContainer（推奨）

VS Code の [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) 拡張機能を使うと、環境構築なしにすぐ開発を始められる。

**前提条件：** Docker、VS Code、Dev Containers 拡張機能

1. このリポジトリをクローン
2. VS Code でフォルダーを開く
3. 右下の通知、またはコマンドパレット（`Ctrl+Shift+P`）から **「Reopen in Container」** を選択
4. 初回のみコンテナーのビルドが実行される（10〜15分程度）

補足：このリポジトリでは、OS パッケージと `uv` を [`.devcontainer/Dockerfile`](.devcontainer/Dockerfile) に含め、ワークスペース依存の初期化だけを [`.devcontainer/postCreate.sh`](.devcontainer/postCreate.sh) で実行する。さらに Dev Container の Node feature に対して `installYarnUsingApt: false` を明示し、Yarn を APT リポジトリではなく Corepack 経由で扱う。ビルド時には `Dockerfile` 側で残存する `yarn.list` も除去し、`apt-get update` が失敗しないようにしている。

コンテナー起動後、ターミナルで以下のコマンドが利用できる：

| コマンド | 内容 |
|----------|------|
| `pnpm mkdocs` | ライブプレビューサーバーを起動（http://localhost:8000） |
| `pnpm mkdocs:build` | 静的サイトをビルド |
| `pnpm mkdocs:build:svg` | Mermaid 図を SVG にレンダリング |
| `pnpm mkdocs:pdf` | PDF を生成 |
| `pnpm lint:text` | textlint でドキュメントを検査 |
| `pnpm lint:text:fix` | textlint で自動修正 |

### Dev Container トラブルシュート

このリポジトリでは [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json) で `installYarnUsingApt: false` を設定し、[`.devcontainer/Dockerfile`](.devcontainer/Dockerfile) の先頭で残存する `yarn.list` を除去したうえで APT パッケージを導入している。既存コンテナーでセットアップが失敗した場合は、以下のどちらかで復旧できる。

1. VS Code で **Dev Containers: Rebuild Container** を実行する
2. 依存関係の同期だけをやり直したい場合は、コンテナー内で `bash .devcontainer/postCreate.sh` を再実行する

## 技術スタック

| 技術 | 用途 |
|------|------|
| Python + uv | MkDocs の実行環境と依存関係管理 |
| MkDocs + Material for MkDocs | 静的サイトジェネレーター |
| MkDocs プラグイン群 | Mermaid の SVG/PNG 変換、PDF 出力、表読込 |
| Node.js + pnpm | Marp と textlint の実行基盤 |
| Mermaid | Markdown内での図表作成 |
| Draw.io | SVG図表作成 |
| Marp | Markdownスライド作成 |
| Playwright | Mermaid 変換時のブラウザ自動化 |
| WeasyPrint | PDF生成 |
| textlint | ドキュメント品質チェック |
