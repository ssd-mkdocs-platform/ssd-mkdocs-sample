# 仕様駆動開発時代のドキュメント基盤

仕様駆動開発時代におけるドキュメント基盤のテンプレート。

Markdown文書を静的サイトジェネレーターでHTMLに変換・公開することで、つぎを実現しする。

- Markdownによる文書記述
- Mermaidによる図表作成
- Draw.ioによるSVG図表作成
- textlintによる品質チェック・フィックスでチームの水準を揃える
- **ハイブリッド公開戦略**:
    - **GitHub Pages**: 正式文書の公開用。GitHub Enterprise のリポジトリ権限により、社内の非開発者を含む広範なユーザー（人数制限なし）への認証付き公開を実現。Mermaid を SVG 形式で埋め込んだ読み込みの速い構成を提供。
    - **Azure Static Web Apps (SWA)**: 開発・プレビュー用。Pull Request 時にプレビュー環境を自動生成。ビルド時間を短縮するため、Mermaid はブラウザレンダリングを使用。
- **高機能な文書出力**:
    - ブラウザ表示用には SVG、PDF 生成用には互換性の高い PNG をビルド時に自動で使い分ける最適化されたパイプライン。
- GitHub Discussions を通じた SWA 閲覧ユーザーへの招待・承認フロー*1

*1: SWA のカスタムロールによる認証は最大 25 人までの制限があるため、主に開発中やレビュー段階の確認用として利用する。

## 技術スタック

| 技術 | 用途 |
|------|------|
| MkDocs + Material for MkDocs | 静的サイトジェネレーター |
| Mermaid | Markdown内での図表作成 |
| Draw.io | SVG図表作成 |
| Playwright | Mermaidレンダリング用ブラウザ自動化 |
| WeasyPrint | PDF生成 |
| textlint | ドキュメント品質チェック |
