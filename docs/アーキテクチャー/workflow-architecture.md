---
title: ワークフロー アーキテクチャ
---

# ワークフロー アーキテクチャ

本リポジトリで使用する GitHub Actions ワークフローの実行条件と内部構造について説明する。

## ワークフロー概要

本システムでは以下の 4 つのワークフローを使用する。

```mermaid
flowchart TB
    subgraph Workflows["GitHub Actions ワークフロー"]
        Deploy["Deploy Site<br/>サイトのビルド・デプロイ"]
        ClosePreview["Close Preview<br/>プレビュー環境削除"]
        RoleSync["Sync Role<br/>ロール同期・招待管理"]
        Textlint["textlint<br/>文書品質チェック"]
    end

    subgraph Triggers["トリガー"]
        Push["git push"]
        PROpen["Pull Request<br/>(open/sync/reopen)"]
        PRClose["Pull Request<br/>(closed)"]
        Schedule["スケジュール<br/>(毎週月曜 12:00 JST)"]
        Manual["手動実行"]
    end

    Push --> Deploy
    Push --> Textlint
    PROpen --> Deploy
    PROpen --> Textlint
    PRClose --> ClosePreview
    Manual --> Deploy
    Manual --> RoleSync
    Manual --> Textlint
    Schedule --> RoleSync
```

| ワークフロー | ファイル | 主な役割 |
|-------------|---------|--------|
| Deploy Site | `.github/workflows/deploy-site.yml` | MkDocs サイトのビルドと GitHub Pages / Azure SWA へのデプロイ |
| Close Preview | `.github/workflows/close-preview.yml` | PR クローズ時に Azure SWA のプレビュー環境を削除 |
| Sync Role | `.github/workflows/role-sync-released.yml` | GitHub 権限に基づく Azure SWA ロールの同期と招待管理 |
| textlint | `.github/workflows/textlint.yml` | Markdown 文書の日本語品質チェック |

---

## Deploy Site ワークフロー

### 実行条件

```mermaid
flowchart TD
    subgraph Triggers["トリガー条件"]
        Push["push to main"]
        PR["Pull Request<br/>(opened/synchronize/reopened)"]
        Manual["workflow_dispatch<br/>(手動実行)"]
    end

    subgraph PathFilter["パスフィルター"]
        Paths["docs/**<br/>mkdocs.yml<br/>pyproject.toml<br/>uv.lock<br/>.github/workflows/deploy-site.yml"]
    end

    Push --> PathFilter
    PR --> PathFilter
    Manual --> |"パスフィルターなし"| Execute
    PathFilter --> |"変更あり"| Execute["ワークフロー実行"]
    PathFilter --> |"変更なし"| Skip["スキップ"]
```

| トリガー | 条件 | パスフィルター |
|---------|------|--------------|
| `push` | `main` ブランチへのプッシュ | `docs/**`, `mkdocs.yml`, `pyproject.toml`, `uv.lock`, `.github/workflows/deploy-site.yml` |
| `pull_request` | opened, synchronize, reopened | 同上 |
| `workflow_dispatch` | 手動実行 | なし（常に実行） |

### 権限

```yaml
permissions:
  contents: read       # リポジトリ読み取り
  pages: write         # GitHub Pages への書き込み
  id-token: write      # OIDC トークン取得
  pull-requests: write # PR コメント
```

### ジョブ構成

ワークフローは `build` ジョブと `deploy-github-pages` ジョブの2つで構成される。

```mermaid
flowchart TD
    subgraph BuildJob["build ジョブ"]
        Checkout["Checkout"]
        Setup["pnpm のインストール<br/>uv のセットアップ<br/>Node.js のセットアップ"]
        InstallDeps["Mermaid CLI のインストール<br/>依存関係の同期<br/>Playwright ブラウザのインストール"]
        
        IsMain{"main + push?"}

        subgraph ProductionSteps["本番デプロイパス"]
            direction TB
            InstallPDF["PDF 依存関係のインストール"]
            BuildWeb["サイトのビルド (Web)"]
            BuildPDF["サイトのビルド (PDF)"]
            DeployAzureProd["Azure Static Web Apps へデプロイ"]
            UploadPages["GitHub Pages 用アーティファクトのアップロード"]
        end

        subgraph PreviewSteps["プレビューデプロイパス"]
            direction TB
            BuildPreview["サイトのビルド (プレビュー)"]
            DeployAzurePreview["Azure Static Web Apps へデプロイ"]
        end
    end

    subgraph PagesJob["deploy-github-pages ジョブ"]
        DeployPages["GitHub Pages へデプロイ"]
    end

    Checkout --> Setup --> InstallDeps --> IsMain

    IsMain --> |"本番: main へ push"| InstallPDF
    InstallPDF --> BuildWeb --> BuildPDF
    BuildPDF --> DeployAzureProd --> UploadPages

    IsMain --> |"プレビュー: PR / 手動実行"| BuildPreview
    BuildPreview --> DeployAzurePreview

    UploadPages --> |"needs: build"| DeployPages

    %% 色の凡例:
    %% - ジョブ: 青系 (#e3f2fd)
    %% - 本番パス: 緑系 (#c8e6c9)
    %% - プレビューパス: 黄系 (#fff8e1)
    style BuildJob fill:#e3f2fd
    style PagesJob fill:#e3f2fd
    style ProductionSteps fill:#c8e6c9
    style PreviewSteps fill:#fff8e1
```

### ジョブ詳細

#### build ジョブ

| ステップ | 説明 | 条件 |
|---------|------|------|
| Checkout | サブモジュール含むチェックアウト | - |
| pnpm のインストール | pnpm パッケージマネージャー | - |
| uv のセットアップ | Python (uv) 環境構築 | - |
| Node.js のセットアップ | Node.js 20 環境構築 | - |
| Mermaid CLI のインストール | `@mermaid-js/mermaid-cli` グローバルインストール | - |
| 依存関係の同期 | `uv sync` による Python 依存関係 | - |
| Playwright ブラウザのインストール | Chromium ブラウザ | - |
| PDF 依存関係のインストール | PDF 生成用システムライブラリ | main + push 時のみ |
| サイトのビルド (Web) | SVG 変換でビルド | main + push 時のみ |
| サイトのビルド (PDF) | PNG 変換 + PDF 生成 | main + push 時のみ |
| サイトのビルド (プレビュー) | 変換なしでビルド | main + push 以外 |
| Azure Static Web Apps へデプロイ | サイトをデプロイ | - |
| GitHub Pages 用アーティファクトのアップロード | Pages 用アーティファクト | main + push 時のみ |

#### deploy-github-pages ジョブ

**依存**: `build` ジョブ完了後  
**実行条件**: main ブランチへの push 時のみ

!!! note "別ジョブとして分離している理由"
    GitHub Pages へのデプロイは `build` ジョブに統合せず、別ジョブとして実装している。理由は以下の通り。
    
    1. **Environments UI での追跡**: `environment` 設定により、GitHub UI の「Environments」タブでデプロイ履歴とステータスを確認可能
    2. **リトライ容易性**: デプロイ失敗時に `build` を再実行せず、デプロイのみをリトライ可能
    3. **公式推奨パターン**: GitHub 公式ドキュメントで推奨されている `upload-pages-artifact` → 別ジョブで `deploy-pages` というパターンに準拠

---

## Close Preview ワークフロー

PR がクローズされた際に、Azure SWA のプレビュー環境を削除する専用ワークフロー。

### 実行条件

```mermaid
flowchart LR
    subgraph Triggers["トリガー条件"]
        PRClose["Pull Request<br/>(closed)"]
    end

    PRClose --> Execute["ワークフロー実行"]
```

| トリガー | 条件 |
|---------|------|
| `pull_request` | closed |

### 権限

```yaml
permissions:
  contents: read  # リポジトリ読み取りのみ
```

### ジョブ構成

```mermaid
flowchart TD
    subgraph ClosePreviewJob["close-preview ジョブ"]
        Close["Azure SWA<br/>プレビュー環境削除"]
    end

    style ClosePreviewJob fill:#ffccbc
```

### ジョブ詳細

#### close-preview ジョブ

Azure Static Web Apps のプレビュー環境を削除する。

| ステップ | 説明 | 使用アクション |
|---------|------|---------------|
| プレビュー環境のクローズ | プレビュー環境の削除 | `Azure/static-web-apps-deploy@v1` |

---

## Sync Role ワークフロー

### 実行条件

```mermaid
flowchart LR
    subgraph Triggers["トリガー条件"]
        Schedule["schedule<br/>cron: '0 3 * * 1'<br/>(毎週月曜 12:00 JST)"]
        Manual["workflow_dispatch<br/>(手動実行)"]
    end

    Triggers --> Execute["ワークフロー実行"]
```

| トリガー | 条件 |
|---------|------|
| `schedule` | 毎週月曜日 03:00 UTC（日本時間 12:00） |
| `workflow_dispatch` | 手動実行 |

### 権限

```yaml
permissions:
  id-token: write    # OIDC トークン取得（Azure 認証用）
  contents: read     # リポジトリ読み取り
  discussions: write # Discussions への書き込み
```

### 環境変数

| 変数 | 説明 | ソース |
|-----|------|-------|
| `SWA_NAME` | Azure Static Web App 名 | `vars.AZURE_SWA_NAME` |
| `SWA_RG` | リソースグループ名 | `vars.AZURE_SWA_RESOURCE_GROUP` |
| `DISCUSSION_CATEGORY` | 招待用カテゴリ名 | `Invitation` (固定値) |

### ジョブ構成

```mermaid
flowchart TD
    subgraph CleanupJob["cleanup ジョブ"]
        GenToken1["GitHub App トークンの生成"]
        CleanupDiscussions["期限切れ Discussion のクリーンアップ"]
    end

    subgraph SyncJob["sync-swa-roles ジョブ"]
        GenToken2["GitHub App トークンの生成"]
        AzureLogin["Azure へログイン (OIDC)"]
        SyncRoles["SWA ロールの同期"]
    end

    GenToken1 --> CleanupDiscussions
    CleanupDiscussions --> |"needs: cleanup"| GenToken2
    GenToken2 --> AzureLogin --> SyncRoles

    style CleanupJob fill:#fff3e0
    style SyncJob fill:#e8f5e9
```

### ジョブ詳細

#### cleanup ジョブ

期限切れの招待 Discussion を削除する。

| ステップ | 説明 | 使用アクション |
|---------|------|---------------|
| GitHub App トークンの生成 | GitHub App からインストールトークンを生成 | `actions/create-github-app-token@v1` |
| 期限切れ Discussion のクリーンアップ | 期限切れ招待を削除 | `nuitsjp/swa-github-discussion-cleanup@v1` |

#### sync-swa-roles ジョブ

**依存**: `cleanup` ジョブ完了後

GitHub リポジトリ権限に基づき Azure SWA のロールを同期し、招待 URL を Discussions に登録する。

| ステップ | 説明 | 使用アクション |
|---------|------|---------------|
| GitHub App トークンの生成 | GitHub App からインストールトークンを生成 | `actions/create-github-app-token@v1` |
| Azure へログイン (OIDC) | OIDC でパスワードレスログイン | `azure/login@v2` |
| SWA ロールの同期 | ロール同期と招待 URL 登録 | `nuitsjp/swa-github-role-sync@v1` |

---

## textlint ワークフロー

### 実行条件

```mermaid
flowchart TD
    subgraph Triggers["トリガー条件"]
        Push["push to main"]
        PR["Pull Request"]
        Manual["workflow_dispatch<br/>(手動実行)"]
    end

    subgraph PathFilter["パスフィルター"]
        Paths[".github/workflows/textlint.yml<br/>docs/**/*.md<br/>*.md<br/>.textlintrc.json<br/>package.json"]
    end

    Push --> PathFilter
    PR --> PathFilter
    Manual --> |"パスフィルターなし"| Execute
    PathFilter --> |"変更あり"| Execute["ワークフロー実行"]
    PathFilter --> |"変更なし"| Skip["スキップ"]
```

| トリガー | 条件 | パスフィルター |
|---------|------|--------------|
| `push` | `main` ブランチへのプッシュ | `.github/workflows/textlint.yml`, `docs/**/*.md`, `*.md`, `.textlintrc.json`, `package.json` |
| `pull_request` | すべてのタイプ | 同上 |
| `workflow_dispatch` | 手動実行 | なし（常に実行） |

### 権限

```yaml
permissions:
  contents: read  # リポジトリ読み取りのみ
```

### ジョブ構成

```mermaid
flowchart TD
    subgraph TextlintJob["textlint ジョブ"]
        Checkout["Checkout"]
        SetupPnpm["pnpm のインストール"]
        SetupNode["Node.js のセットアップ"]
        Install["依存関係のインストール"]
        Lint["textlint の実行"]
    end

    Checkout --> SetupPnpm --> SetupNode --> Install --> Lint

    style TextlintJob fill:#fce4ec
```

### ジョブ詳細

#### textlint ジョブ

Markdown 文書の日本語品質をチェックする。

| ステップ | 説明 | 備考 |
|---------|------|-----|
| Checkout | リポジトリのチェックアウト | - |
| pnpm のインストール | pnpm パッケージマネージャー | - |
| Node.js のセットアップ | Node.js 20 環境構築 | pnpm キャッシュ有効 |
| 依存関係のインストール | pnpm install | `--frozen-lockfile` で厳密インストール |
| textlint の実行 | pnpm run lint:text | エラー時はワークフロー失敗 |

---

## ワークフロー間の関係

```mermaid
flowchart TB
    subgraph Development["開発フロー"]
        Code["コード変更"]
        PR["Pull Request"]
        Merge["main へマージ"]
    end

    subgraph CI["継続的インテグレーション"]
        Textlint["textlint<br/>品質チェック"]
    end

    subgraph CD["継続的デプロイ"]
        Deploy["Deploy Site"]
        Preview["プレビュー環境"]
        Production["本番環境<br/>(Pages + Azure)"]
    end

    subgraph Automation["自動化"]
        RoleSync["Sync Role<br/>(週次実行)"]
    end

    Code --> Textlint
    Code --> PR
    PR --> Textlint
    PR --> Deploy --> Preview
    Merge --> Deploy --> Production
    RoleSync --> |"ロール同期"| Production
```

## 関連ドキュメント

- [デプロイ構成](deploy-architecture.md) - デプロイアーキテクチャの詳細
- [テキスト校正](text-validation.md) - textlint のルール設定
- [クラウド環境構築](../cloud-resources-setup.md) - Azure / GitHub リソースの構築手順
