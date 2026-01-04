---
title: Marp
---

# Marp

Marpはマークダウンからプレゼンテーション資料を作成するツールです。本プロジェクトではMkDocsと統合してWebで表示します。

## 概要

MarpはMarkdown形式でスライドを記述し、HTML/PDF/PPTXなどに変換できるツールです。

本プロジェクトでの特徴：

- MkDocsのページとしてWeb上で閲覧可能
- PDF出力はMkDocsのto-pdfプラグインで統合的に行う
- スライド単体のPDF出力も可能

## 基本構文

### スライドの区切り

スライドは`---`（水平線）で区切ります。

```markdown
---
marp: true
---

# スライド1

最初のスライドの内容

---

# スライド2

2枚目のスライドの内容

---

# スライド3

3枚目のスライドの内容
```

### フロントマター

スライドの先頭にフロントマターを記述して設定を行います。

```markdown
---
marp: true
theme: default
paginate: true
header: 'ヘッダーテキスト'
footer: 'フッターテキスト'
---
```

主な設定項目：

| 設定 | 説明 |
|------|------|
| `marp: true` | Marpスライドとして認識させる |
| `theme` | テーマ（default, gaia, uncover） |
| `paginate` | ページ番号を表示 |
| `header` | ヘッダーテキスト |
| `footer` | フッターテキスト |
| `size` | スライドサイズ（16:9, 4:3） |

## スタイリング

### ディレクティブ

スライドごとにスタイルを変更できます。

```markdown
---

<!-- _class: lead -->
# タイトルスライド

中央寄せのリードスライド

---

<!-- _backgroundColor: #123 -->
<!-- _color: white -->
# 背景色を変更

このスライドは背景が暗い

---
```

### 画像の配置

```markdown
---

# 画像の配置

![width:300px](../assets/images/my-diagram.drawio.svg)

<!-- 背景画像として使用 -->
![bg right:40%](../assets/images/background.png)

---
```

画像の指定方法：

- `width:300px` - 幅を指定
- `height:200px` - 高さを指定
- `bg` - 背景画像として使用
- `bg right:40%` - 右側40%に背景画像

## サンプルスライド

以下はMarpで作成したスライドの例です。

---
marp: true
theme: default
paginate: true
---

# プロジェクト概要

仕様駆動開発時代のドキュメント基盤

---

## 技術スタック

- MkDocs + Material for MkDocs
- Mermaid（ダイアグラム）
- Draw.io（複雑な図）
- Marp（プレゼンテーション）

---

## ワークフロー

```mermaid
graph LR
    A[Markdown作成] --> B[ローカルプレビュー]
    B --> C[コミット]
    C --> D[自動デプロイ]
```

---

## まとめ

- テキストベースでドキュメント管理
- バージョン管理が容易
- 自動ビルド・デプロイ

---

## VS Code拡張

Marp for VS Code拡張を使用すると、エディター内でプレビューを確認できます。

1. VS Codeを開く
2. 拡張機能で「Marp for VS Code」を検索
3. インストール

## PDF出力

### MkDocs統合でのPDF

MkDocsサイト全体をPDF化する場合は、to-pdfプラグインを使用します。

```bash
MKDOCS_PDF=1 uv run mkdocs build
```

### スライド単体のPDF

Marp CLIを使用してスライド単体をPDF化できます。

```bash
# Marp CLIのインストール
npm install -g @marp-team/marp-cli

# PDFに変換
marp slides.md --pdf
```

### HTMLに変換

```bash
marp slides.md --html
```

## ファイル配置

Marpスライドはdocsディレクトリ内の任意の場所に配置できます。

```
docs/
├── presentations/
│   ├── project-overview.md
│   └── technical-design.md
└── samples/
    └── marp.md
```

## 参考リンク

- [Marp公式サイト](https://marp.app/)
- [Marp for VS Code](https://marketplace.visualstudio.com/items?itemName=marp-team.marp-vscode)
- [Marpit Markdown](https://marpit.marp.app/markdown)
