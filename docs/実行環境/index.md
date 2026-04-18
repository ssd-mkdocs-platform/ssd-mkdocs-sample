---
title: 実行環境
---

# 実行環境

このセクションでは、`MkDocs` サンプルを支える実行環境を説明する。

実行環境（Docker イメージ、Azure Container Apps スクリプト、ハンズオン配布インフラ）は別リポジトリ [genai-docs/genai-docs-env](https://github.com/genai-docs/genai-docs-env) に切り出して管理している。本リポジトリはサンプル本体（ドキュメント内容と DevContainer 設定）に集中する。

## 役割分担

- サンプル本体（当リポジトリ）： `docs/`, `mkdocs.yml`, `pyproject.toml`, `package.json`, `mise.toml`, `.devcontainer/`
- 実行環境（[genai-docs-env](https://github.com/genai-docs/genai-docs-env)）： Docker イメージ定義、Azure Container Apps 運用スクリプト、Bicep、GHCR 公開 CI

## ドキュメント

- [クラウド環境構築](cloud-resources-setup.md) - GitHub Pages / Azure Static Web Appsの公開基盤を構築する
- [ハンズオン環境設計](handson.md) - Azure Container Appsを使った配布用環境の設計方針
- [ハンズオン環境情報](environment.md) - 実装と運用導線の対応関係
