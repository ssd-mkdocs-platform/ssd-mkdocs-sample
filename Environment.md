# ハンズオン実行環境 アーキテクチャ

## リソース一覧

| リソース種別 | 数量 | 概略 |
|---|---|---|
| Container Registry (Basic) | 1 | ハンズオン用コンテナイメージの格納先 |
| User Assigned Managed Identity | 1 | Container Apps → ACR 間のパスワードレス認証 |
| Log Analytics Workspace | 1 | コンテナログの収集・トラブルシューティング用 |
| Container Apps Environment | 1 | 全参加者のコンテナが稼働する共有実行基盤 |
| Container App | 参加者数 | 参加者ごとのcode-server環境（1 vCPU / 2 GiB） |

## 全体像

参加者がブラウザのみでハンズオン作業を行えるよう、Azure上にひとりひとり専用のコンテナ環境を提供する構成である。

```
参加者 (ブラウザ)
    │
    │ HTTPS (パスワード認証)
    ▼
┌─────────────────────────────────────────────────┐
│  Container Apps Environment                      │
│  (全参加者で共有する実行基盤)                      │
│                                                  │
│  ┌──────────┐ ┌──────────┐     ┌──────────┐     │
│  │ user-01  │ │ user-02  │ ... │ user-N   │     │
│  │          │ │          │     │          │     │
│  │ code-    │ │ code-    │     │ code-    │     │
│  │ server   │ │ server   │     │ server   │     │
│  │ :8080    │ │ :8080    │     │ :8080    │     │
│  └──────────┘ └──────────┘     └──────────┘     │
│       │                                          │
│       │ ログ収集                                  │
│       ▼                                          │
│  Log Analytics                                   │
└─────────────────────────────────────────────────┘
        ▲
        │ イメージ取得 (Managed Identity 認証)
        │
   Container Registry
   (ハンズオン用イメージを格納)
```

## 構成要素の役割

### Container Registry

ハンズオン用コンテナイメージの保管場所。code-server・MkDocs・VS Code拡張機能・ハンズオン資材をすべて含んだイメージを格納する。イメージタグにはGitコミットハッシュを使用し、どのリビジョンのソースから構築されたかを追跡できるようにしている。

### Managed Identity

Container AppsがContainer Registryからイメージを取得する際の認証手段。AcrPullロールのみを付与し、イメージの読み取り専用アクセスに制限している。パスワードやトークンをContainer Appの設定に埋め込む必要がなくなり、資格情報の漏洩リスクを排除する。

### Log Analytics Workspace

Container Apps Environmentのログ収集先。参加者のコンテナが起動しない、応答しないといった問題が発生した際に、ログを確認してトラブルシューティングを行うために使用する。

### Container Apps Environment

全参加者のContainer Appが稼働する共有実行基盤。ネットワーク・ログ収集・DNS解決などの基盤機能を提供する。各Container Appにはこの環境のドメインをベースとした一意のFQDNが割り当てられる。

### Container App（参加者ごと）

参加者ひとりにつき1台デプロイされるコンテナ。以下の特性を持つ。

- **code-server（port 8080）** をIngressで外部HTTPS公開し、ブラウザからVS Code相当の操作環境を提供する
- **パスワード認証**により、割り当てられた参加者のみがアクセスできる
- **min-replicas=1** を設定し、スケールインによるコンテナ停止を防止する
- 参加者がターミナルから`mkdocs serve`を起動し、コンテナ内部のport 8000でプレビューをSimple Browserから閲覧する（外部には公開しない）

## デプロイの仕組み

環境の構築は `scripts/Deploy-HandsonEnv.ps1` で一括実行する。内部では2段階のBicepテンプレートを使用している。

1. **`infra/main.bicep`** — Container Registry・Managed Identity・Log Analytics・Container Apps Environmentの共有インフラをデプロイ
2. **`infra/container-app.bicep`** — 参加者ごとのContainer Appをデプロイ（パスワードを個別生成）

イメージのビルドは `az acr build` でContainer Registry上で実行し、ローカルのDocker環境を不要としている。

## コスト見通し

Visual Studio Enterpriseサブスクリプション付帯のAzureクレジット（$150/月 ≒ 24,000円/月）内での運用を前提とする。

> 以下の円換算は $1 = 160円 で算出している。

### 固定費（常時課金）

| リソース | 概算 | 備考 |
|---|---|---|
| Container Registry (Basic) | 約800円/月 | イメージ保管。ハンズオン終了後に削除すれば課金停止 |

### 従量課金（ハンズオン開催時のみ）

| リソース | 単価 | 備考 |
|---|---|---|
| Container App (1 vCPU / 2 GiB) | 約10円/時間/台 | Consumptionプラン。稼働時間のみ課金 |

### 想定シナリオ

| 規模 | 時間 | Container Apps | ACR | 合計 |
|---|---|---|---|---|
| 10名 × 4時間 | 半日 | 約400円 | 800円 | 約1,200円 |
| 20名 × 4時間 | 半日 | 約800円 | 800円 | 約1,600円 |
| 20名 × 8時間 | 終日 | 約1,600円 | 800円 | 約2,400円 |

いずれのケースもクレジット上限（約24,000円/月）に対して十分な余裕がある。ハンズオン終了後にリソースグループを削除すれば、以降の課金は発生しない。

## 環境のライフサイクル

| フェーズ | 操作 |
|---|---|
| 構築 | `Deploy-HandsonEnv.ps1 -UserCount N` を実行 |
| 当日運用 | 参加者に配布されたURL・パスワードでブラウザからアクセス |
| 片付け | `Remove-HandsonEnv.ps1` でリソースグループごと一括削除 |
