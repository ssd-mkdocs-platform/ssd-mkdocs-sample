---
title: デプロイ構成
---

# デプロイ構成

本ドキュメント基盤のデプロイアーキテクチャについて説明する。

## 概要

本システムは GitHub と Azure を組み合わせたハイブリッド構成で、以下の特徴を持つ。

- **デュアルデプロイ**: GitHub Pages と Azure Static Web Apps（SWA）への同時デプロイ
- **PRプレビュー**: Pull Request 作成時に Azure SWA でプレビュー環境を自動生成
- **OIDC認証**: GitHub Actions から Azure へのパスワードレス認証
- **ロールベースアクセス制御**: GitHub リポジトリ権限に基づく閲覧制御（SWA）

## 配置モデル

```mermaid
flowchart TB
    subgraph Clients["クライアント"]
        Browser["ブラウザ"]
        Developer["開発者"]
    end

    subgraph GitHub["GitHub"]
        subgraph Repository["リポジトリ"]
            Source["ソースコード<br/>docs/ | mkdocs.yml"]
            Workflows["GitHub Actions<br/>ワークフロー"]
        end

        subgraph GitHubServices["GitHub サービス"]
            Pages["GitHub Pages"]
            Discussions["GitHub Discussions"]
            GitHubApp["GitHub App"]
        end

        subgraph GitHubConfig["設定"]
            Secrets["Secrets"]
            Variables["Variables"]
        end
    end

    subgraph Azure["Azure"]
        subgraph ResourceGroup["Resource Group<br/>rg-{repo}-prod"]
            SWA["Static Web App<br/>stapp-{repo}-prod"]
            ManagedIdentity["Managed Identity<br/>id-{repo}-prod"]
        end

        subgraph Security["セキュリティ"]
            FederatedCredential["Federated Credential<br/>OIDC"]
            RBAC["RBAC<br/>Contributor"]
        end
    end

    Developer -->|git push| Source
    Source -->|トリガー| Workflows

    Workflows -->|デプロイ| Pages
    Workflows -->|デプロイ| SWA
    Workflows -->|OIDC認証| FederatedCredential

    FederatedCredential -->|検証| ManagedIdentity
    ManagedIdentity -->|権限| RBAC
    RBAC -->|操作| SWA

    GitHubApp -->|API| Discussions
    Workflows -->|トークン生成| GitHubApp

    Secrets -->|認証情報| Workflows
    Variables -->|設定値| Workflows

    Browser -->|閲覧<br/>パブリック| Pages
    Browser -->|閲覧<br/>認証付き| SWA
```

## コンポーネント詳細

### GitHub 側リソース

| リソース | 用途 |
|----------|------|
| リポジトリ | Markdown ソース、MkDocs 設定、ワークフロー定義を格納 |
| GitHub Actions | CI/CD パイプライン。ビルド・デプロイ・ロール同期を実行 |
| GitHub Pages | 静的サイトのパブリック公開（Enterprise で認証制御可能） |
| GitHub Discussions | SWA の招待管理。閲覧権限のリクエストを受け付け |
| GitHub App | Discussions API への書き込み権限を持つアプリケーション |
| Secrets | `AZURE_SWA_API_TOKEN`, `ROLE_SYNC_APP_PRIVATE_KEY` |
| Variables | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_SWA_NAME`, `AZURE_SWA_RESOURCE_GROUP`, `ROLE_SYNC_APP_ID` |

### Azure 側リソース

| リソース | 用途 |
|----------|------|
| Resource Group | 関連リソースをグルーピング |
| Static Web App | 静的サイトのホスティング。認証・認可機能を内蔵 |
| Managed Identity | GitHub Actions が Azure を操作するための ID |
| Federated Credential | OIDC による GitHub Actions との信頼関係 |
| RBAC | Managed Identity に SWA への Contributor 権限を付与 |

## デプロイフロー

### 本番デプロイ（main ブランチ）

```mermaid
sequenceDiagram
    participant Dev as 開発者
    participant GH as GitHub
    participant Actions as GitHub Actions
    participant SWA as Azure SWA
    participant Pages as GitHub Pages

    Dev->>GH: git push main
    GH->>Actions: ワークフロー起動

    Actions->>Actions: uv sync
    Actions->>Actions: mkdocs build<br/>(PDF有効)

    par デュアルデプロイ
        Actions->>SWA: アーティファクトをアップロード
        Actions->>Pages: アーティファクトをアップロード
    end

    Note over SWA,Pages: 同一コンテンツを両環境に配信
```

### PR プレビュー

```mermaid
sequenceDiagram
    participant Dev as 開発者
    participant GH as GitHub
    participant Actions as GitHub Actions
    participant SWA as Azure SWA

    Dev->>GH: Pull Request 作成
    GH->>Actions: ワークフロー起動

    Actions->>Actions: mkdocs build
    Actions->>SWA: プレビュー環境にデプロイ
    SWA-->>GH: プレビューURLをコメント

    Dev->>GH: Pull Request マージ
    GH->>Actions: close イベント
    Actions->>SWA: プレビュー環境を削除
```

### ロール同期

```mermaid
sequenceDiagram
    participant Schedule as スケジュール<br/>(毎週月曜 12:00 JST)
    participant Actions as GitHub Actions
    participant App as GitHub App
    participant Discussions as GitHub Discussions
    participant Entra as Microsoft Entra ID
    participant SWA as Azure SWA

    Schedule->>Actions: ワークフロー起動

    Actions->>App: トークン生成
    App-->>Actions: インストールトークン

    Actions->>Discussions: 期限切れ招待を削除

    Actions->>Entra: OIDC トークン要求
    Entra-->>Actions: アクセストークン

    Actions->>SWA: ロール情報を同期
    Note over SWA: GitHub権限に基づき<br/>SWAロールを更新
```

## 認証・認可モデル

### OIDC フェデレーション

GitHub Actions から Azure への認証には OIDC（OpenID Connect）を使用する。これによりシークレットの長期保存が不要となる。

```mermaid
flowchart LR
    subgraph GitHub
        Actions["GitHub Actions"]
    end

    subgraph Azure
        Entra["Microsoft Entra ID"]
        MI["Managed Identity"]
        SWA["Static Web App"]
    end

    Actions -->|1. OIDC トークン| Entra
    Entra -->|2. 検証| MI
    MI -->|3. アクセストークン| Actions
    Actions -->|4. API 呼び出し| SWA
```

**信頼関係の設定**:

- **Issuer**: `https://token.actions.githubusercontent.com`
- **Subject**: `repo:{owner}/{repo}:ref:refs/heads/main`
- **Audience**: `api://AzureADTokenExchange`

### SWA 認証フロー

Azure Static Web Apps は組み込みの認証機能を提供する。

```mermaid
flowchart LR
    User["ユーザー"] -->|1. アクセス| SWA["Static Web App"]
    SWA -->|2. 認証要求| AAD["Microsoft Entra ID<br/>/ GitHub / etc."]
    AAD -->|3. 認証完了| SWA
    SWA -->|4. ロール確認| Roles["ロール設定"]
    Roles -->|5. 認可| Content["コンテンツ"]
```

## 環境構成の比較

| 項目 | GitHub Pages | Azure Static Web Apps |
|------|--------------|----------------------|
| URL | `{owner}.github.io/{repo}` | `*.azurestaticapps.net` |
| 認証 | なし（Enterprise で可能） | Microsoft Entra ID / GitHub / カスタム |
| PRプレビュー | なし | あり（自動生成） |
| カスタムドメイン | 可能 | 可能 |
| 料金 | 無料 | Free / Standard |

## 関連ドキュメント

- [クラウド環境構築](../cloud-resources-setup.md) - Azure / GitHub リソースの構築手順
- [テキスト校正](text-validation.md) - textlint による品質管理
