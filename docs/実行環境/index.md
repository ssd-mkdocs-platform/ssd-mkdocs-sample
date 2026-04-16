---
title: 実行環境
---

# 実行環境

このセクションでは、`MkDocs` サンプルを支える専用実行環境を説明する。

このリポジトリは文書基盤サンプルが主役であり、実行環境はその再現性と配布性を担保するために同じリポジトリへ同居させている。

## 役割分担

- サンプル本体: `docs/`, `mkdocs.yml`, `pyproject.toml`, `package.json`, `mise.toml`
- ローカル開発環境: `.devcontainer/`, `infra/docker/`
- ハンズオン運用: `infra/azure/`, `infra/scripts/`, `settings.template.json`

## ドキュメント

- [クラウド環境構築](cloud-resources-setup.md) - GitHub Pages / Azure Static Web Apps の公開基盤を構築する
- [ハンズオン環境設計](handson.md) - Azure Container Apps を使った配布用環境の設計方針
- [ハンズオン環境情報](environment.md) - 実装と運用導線の対応関係
