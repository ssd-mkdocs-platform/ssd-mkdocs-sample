# 生成AI時代のドキュメント基盤

このリポジトリは、`MkDocs` を中心にしたドキュメント基盤サンプルである。文書ソース、公開設定、品質チェック、PDF 出力、サンプル図表をひとまとめにし、再現可能な開発・配布環境も同じリポジトリで管理する。

主役はサンプル本体であり、実行環境はその専用付帯機能として設計している。

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

## このリポジトリでできること

- Markdown で文書を記述する
- Mermaid と Draw.io の図表を管理する
- `MkDocs` でサイトを生成し、PDF も出力する
- `textlint` で文書品質を統一する
- GitHub Pages / Azure Static Web Apps で公開する

## 役割分担

- サンプル本体: `docs/`, `mkdocs.yml`, `pyproject.toml`, `package.json`, `mise.toml`
- ローカル開発環境: `.devcontainer/`, `infra/docker/`
- ハンズオン運用: `infra/azure/`, `infra/scripts/`, `settings.template.json`

## 最短導線

```bash
mise install
mise run setup
mise run mkdocs
```

詳しい手順は以下を参照する。

- [利用方法](usage-guide.md)
- [ユーザー環境構築](user-environment-setup.md)
- [実行環境の概要](実行環境/index.md)
- [サンプル一覧](サンプル/index.md)

## 補足

公開・運用・デプロイ構成の詳細は、`アーキテクチャー` と `実行環境` の各セクションに集約している。トップレベル README は入口に留め、詳細な説明はこのサイトを正本とする。
