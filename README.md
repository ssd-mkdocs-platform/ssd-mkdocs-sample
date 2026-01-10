# 仕様駆動開発時代のドキュメント基盤

仕様駆動開発時代におけるドキュメント基盤のテンプレート。

Markdown文書を静的サイトジェネレーターでHTMLに変換・公開することで、つぎを実現しする。

- Markdownによる文書記述
- Mermaidによる図表作成
- Draw.ioによるSVG図表作成
- textlintによる品質チェック・フィックスでチームの水準を揃える
- GitHub Pages*1 もしくはAzure Static Web Apps（以降SWA）による正式文書公開
- Pull Request時にSWAでのプレビュー
- GitHubリポジトリの権限に応じたセキュリティ管理*1

*1: GitHub Pagesでリポジトリ権限に応じた閲覧制御を行うには、GitHub Enterpriseプランが必要

## 技術スタック

| 技術 | 用途 |
|------|------|
| MkDocs + Material for MkDocs | 静的サイトジェネレーター |
| Mermaid | Markdown内での図表作成 |
| Draw.io | SVG図表作成 |
| Playwright | Mermaidレンダリング用ブラウザ自動化 |
| WeasyPrint | PDF生成 |
| textlint | ドキュメント品質チェック |
