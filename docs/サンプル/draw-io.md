---
title: Draw.io
---

# Draw.io

Draw.ioはGUIベースで図を作成できるツールである。VS CodeのDraw.io Integration拡張を使用して、エディター内で直接編集できる。

## 使用する場面

Draw.ioは以下のような場面で使用する。

- Mermaidでは表現が難しい複雑な図
- 接続線の位置を細かく制御したい場合
- 自由なレイアウトが必要な場合
- アイコンやイラストを含む図

## 注意事項

**Draw.ioはどうしても必要な理由があるときのみ使用すること。**

理由：

- バイナリ形式に近いため、AIによる解釈・生成が困難
- 差分の確認が難しい
- テキストベースのMermaidと比較してバージョン管理が複雑

基本的な図（フローチャート、シーケンス図、状態遷移図など）は[Mermaid](mermaid.md)を使用すること。

## セットアップ

### VS Code拡張のインストール

1. VS Codeを開く
2. 拡張機能マーケットプレイスで「Draw.io Integration」を検索
3. 「Draw.io Integration」（hediet.vscode-drawio）をインストール

## ファイル形式

Draw.ioで作成するファイルは`.drawio.svg`形式を使用する。

**SVG形式を使用する理由：**

- ベクター形式のため、Webで閲覧しやすく拡大縮小が可能
- PDF化する際に、MkDocsのsvg-to-pngプラグインでPNGに変換できる

## 使い方

### 新規作成

1. 対象の文書と同じディレクトリに`.drawio.svg`ファイルを作成
   - 例： `overview.md` の図なら `overview-architecture.drawio.svg`
2. VS Codeでファイルを開くと、Draw.ioエディターが起動
3. 図を作成・編集
4. 保存（Ctrl+S）

### Markdownでの参照

同じディレクトリにあるため、相対パスで簡潔に参照できる。

```markdown
![アーキテクチャ図](./overview-architecture.drawio.svg)
```

## ファイル配置のルール

Draw.ioファイルは、関連する文書と同じディレクトリに配置する。

```
docs/
├── section-a/
│   ├── overview.md
│   ├── overview-architecture.drawio.svg
│   └── detail/
│       ├── api-design.md
│       └── api-design-flow.drawio.svg
```

### 命名規則

`{文書名}-{図の内容}.drawio.svg`

- 文書名： 関連するMarkdownファイルの名前（拡張子なし）
- 図の内容： 図が表す内容を簡潔に表現
- 例： `api-design-flow.drawio.svg`, `system-architecture.drawio.svg`

### この配置方式の理由

1. **近接性**: 文書と関連図が同じディレクトリにあり、関係が明確
2. **移動・削除の容易さ**: 文書を移動・削除する際、関連ファイルも一緒に扱える
3. **命名による関連付け**: ファイル名で所属する文書が明確
4. **スケーラビリティ**: 階層が深くなっても管理が破綻しない
5. **git追跡可能**: `docs/assets/images/` はMkDocs生成画像用でgitignore対象のため、文書と同じ場所に配置

## 参考リンク

- [Draw.io公式サイト](https://www.drawio.com/)
- [VS Code Draw.io Integration](https://marketplace.visualstudio.com/items?itemName=hediet.vscode-drawio)
