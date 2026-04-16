# ハンズオン実行環境

この文書は、ハンズオン実行環境の全体像と運用導線をまとめたものである。Azure リソース定義や各パラメーターの詳細は文書に重複記載せず、実装そのものを正として Bicep / スクリプトを参照する。

## 構成概要

参加者がブラウザのみで作業できるよう、Azure Container Apps 上に参加者ごとの `code-server` 環境をデプロイする。コンテナイメージは `ghcr.io` に格納し、Container Apps から取得する。

```text
参加者 (ブラウザ)
    │
    │ HTTPS + パスワード認証
    ▼
Container App (参加者ごと)
    │
    ├─ code-server : 8080
    └─ mkdocs serve : 8000
         ※ 参加者が必要に応じて起動
         ※ 外部公開はしない

        ↑
        │ 配置先
        │
Container Apps Environment
        │
        └─ ログ送信先: Log Analytics Workspace

        ↑
        │ イメージ取得
        │
GitHub Container Registry (ghcr.io)
```

## 実装との対応

現在の実装では、環境構築に関わる主要ファイルは以下のとおりである。

- インフラのエントリーポイント: `infra/scripts/Deploy-HandsonEnv.ps1`
- イメージビルド: `infra/scripts/Build-Image.ps1`
- 環境削除: `infra/scripts/Remove-HandsonEnv.ps1`
- 共有インフラ定義: `infra/azure/main.bicep`
- 参加者用アプリ定義: `infra/azure/container-app.bicep`
- 実行コンテナ定義: `infra/docker/Dockerfile`
- デプロイ設定: `settings.local.json`

詳細な Azure リソース定義、Container App の構成、パラメーター、命名規則、出力値は Bicep を参照すること。

## 運用フロー

### 構築

環境構築は `infra/scripts/Deploy-HandsonEnv.ps1` から実行する。スクリプトは `settings.local.json` を読み込み、必要に応じてコンテナイメージをビルド・プッシュし、その後 Azure 上へ共有インフラと参加者用 Container App 群をデプロイする。

参加者情報の出力やログは、リポジトリ直下の `handson-out/` に保存される。

### 当日運用

参加者は配布された URL とパスワードで `code-server` にログインする。`mkdocs serve` の起動は参加者の操作で行い、プレビューはコンテナ内部の `localhost:8000` を利用する前提である。

### 片付け

環境削除は `infra/scripts/Remove-HandsonEnv.ps1` を利用する。削除対象の判定方法や一括削除の挙動はスクリプト実装を参照すること。

## 補足

- 実行コンテナは `infra/docker/Dockerfile` で定義している。
- ローカル開発用 Dev Container は `.devcontainer/devcontainer.json` で同じ Dockerfile を参照している。
- 実装詳細を文書へ転記しすぎると乖離しやすいため、構成や挙動の正確な確認はコードを優先する。
