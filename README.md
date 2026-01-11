# 仕様駆動開発時代のドキュメント基盤

仕様駆動開発時代におけるドキュメント基盤テンプレート。

特徴：

1. ヒューマン フレンドリー
2. AI フレンドリー
3. ポータブル

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

## 技術スタック

| 技術 | 用途 |
|------|------|
| MkDocs + Material for MkDocs | 静的サイトジェネレーター |
| Mermaid | Markdown内での図表作成 |
| Draw.io | SVG図表作成 |
| Playwright | Mermaidレンダリング用ブラウザ自動化 |
| WeasyPrint | PDF生成 |
| textlint | ドキュメント品質チェック |
