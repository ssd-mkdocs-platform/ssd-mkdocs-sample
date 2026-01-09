---
title: テキスト校正
---

# テキスト校正

このプロジェクトでは、textlintを使用して日本語文書の品質を自動的にチェックする。

## 概要

textlintは、自然言語（日本語、英語など）で書かれた文章をルールベースで検証するツールである。文法の誤り、表記の揺れ、スタイルの不統一を自動的に検出し、一貫性のある高品質な文書を維持できる。

## 使用しているルール

### 基本ルール

#### `no-mix-dearu-desumasu`

「だ・である調」と「です・ます調」の混在を検出する。

```json
"no-mix-dearu-desumasu": true
```

このプロジェクトでは「だ・である調」で統一している。

### preset-japanese

日本語文書の一般的なルールセットである。

#### `sentence-length`

文の長さを制限する（最大150文字）。

```json
"sentence-length": { "max": 150 }
```

**理由**: 長すぎる文は読みにくく、理解しづらくなる。

#### `max-ten`

1つの文中の読点（、）の数を制限する（最大4つ）。

```json
"max-ten": { "max": 4 }
```

**理由**: 読点が多すぎる文は、複数の文に分割したほうが読みやすくなる。

#### `no-doubled-joshi`

同じ助詞の連続使用を検出する。

```json
"no-doubled-joshi": {
  "min_interval": 1,
  "strict": false,
  "allow": ["も", "や", "か"],
  "separatorChars": ["、", "。", "?", "!", "？", "！", "「", "」"]
}
```

**理由**: 同じ助詞の重複を検出する。これにより、文章の不自然さを防ぐ。

### preset-ja-spacing

日本語文書のスペーシングルールである。

```json
"preset-ja-spacing": {
  "ja-space-between-half-and-full-width": false,
  "ja-space-around-code": false
}
```

- **`ja-space-between-half-and-full-width`**: 無効化（全角と半角の間にスペースを入れない）
- **`ja-space-around-code`**: 無効化（コード前後のスペースを強制しない）

**理由**: 技術文書ではコード例や英数字が頻繁に登場するため、厳密なスペーシングルールを適用しない。

### preset-jtf-style

JTF（日本翻訳連盟）のスタイルガイドに基づくルールである。

主要な設定：

```json
"preset-jtf-style": {
  "1.2.1.句点(。)と読点(、)": true,
  "1.2.2.ピリオド(.)とカンマ(,)": true,
  "2.1.8.算用数字": true,
  "2.2.2.算用数字と漢数字の使い分け": true,
  "3.1.1.全角文字と半角文字の間": false,
  "3.1.2.全角文字どうし": true,
  "4.1.3.ピリオド(.)、カンマ(,)": true,
  "4.2.6.ハイフン(-)": false,
  "4.3.1.丸かっこ（）": true,
  "4.3.2.大かっこ［］": true
}
```

**無効化しているルール**:

- `3.1.1.全角文字と半角文字の間`: 技術文書では現実的ではないため
- `4.2.6.ハイフン(-)`: コマンドラインオプションなどで使用するため

### prh（表記ゆれ検出）

ICS MEDIAのtextlint校正辞書を使用している。

```json
"prh": {
  "rulePaths": [
    "./node_modules/textlint-rule-preset-icsmedia/dict/prh.yml"
  ]
}
```

このルールセットには以下が含まれる：

- **誤字**: よくある誤字を検出
- **ひらく漢字**:「ください」→「ください」など
- **冗長な表現**:「〜できる」→「〜できる」など
- **重言**:「頭痛が痛い」などの重複表現
- **外来語カタカナ表記**:「エディター」→「エディター」など（長音符号ルール）
- **固有名詞**: 企業名、製品名の正しい表記
- **技術用語**: Web技術用語の正しい表記

## セットアップ

### 必要なツール

- Node.js（npmを使用するため）
- VS Code拡張： `3w36zj6.textlint`

### 依存パッケージのインストール

```bash
npm install
```

このコマンドで、以下のパッケージがインストールされる：

- `textlint`: 本体
- `textlint-rule-no-mix-dearu-desumasu`: 文体統一ルール
- `textlint-rule-preset-japanese`: 日本語ルールセット
- `textlint-rule-preset-ja-spacing`: スペーシングルール
- `textlint-rule-preset-jtf-style`: JTFスタイルガイド
- `textlint-rule-prh`: 表記ゆれ検出
- `textlint-rule-preset-icsmedia`: ICS MEDIA校正辞書

### VS Code設定

プロジェクトの`.vscode/settings.json`に以下を設定している：

```json
{
  "textlint.configPath": ".textlintrc.json",
  "textlint.autoFixOnSave": false,
  "textlint.run": "onType"
}
```

- **`configPath`**: 設定ファイルのパス
- **`autoFixOnSave`**: 保存時の自動修正を無効化（手動で確認してから修正するため）
- **`run`**: 入力中にリアルタイムでチェック

## 使い方

### コマンドラインでのチェック

#### すべてのMarkdownファイルをチェック

```bash
npm run lint:text
```

#### 自動修正を適用

```bash
npm run lint:text:fix
```

**注意**: 自動修正は機械的に行われるため、修正内容を必ず確認すること。

#### 特定のファイルをチェック

```bash
npx textlint docs/samples/draw-io.md
```

#### 特定のファイルを自動修正

```bash
npx textlint --fix docs/samples/draw-io.md
```

### VS Code拡張でのチェック

textlint拡張がインストールされていれば、以下の機能が使える：

1. **リアルタイムチェック**: 入力中に自動的にエラーを検出
2. **問題タブ**: VS Codeの「問題」タブにエラー一覧を表示
3. **波線表示**: エラー箇所にエディター上で波線を表示
4. **クイックフィックス**: 修正候補を提示（電球アイコンまたはCtrl+.）

## トラブルシューティング

### VS Codeの「問題」タブにエラーが表示されない

#### 1. VS Codeを再読み込み

設定変更後は、VS Codeウィンドウを再読み込みすること：

- コマンドパレット（Ctrl+Shift+P）→「**Developer: Reload Window**」

#### 2. textlint拡張がインストールされているか確認

- 拡張機能ビュー（Ctrl+Shift+X）で `3w36zj6.textlint` を検索
- インストール済みで有効になっているか確認

#### 3. node_modulesが存在するか確認

```bash
ls node_modules
```

存在しない場合は `npm install` を実行すること。

#### 4. 出力パネルでログを確認

1. 表示 → 出力（Ctrl+Shift+U）
2. ドロップダウンで「**textlint**」を選択
3. エラーメッセージを確認

よくあるエラー：

- `.textlintrc.json` の読み込みエラー
- `node_modules` へのパス解決の問題
- textlintルールの読み込みエラー

#### 5. 設定ファイルの構文エラーを確認

`.textlintrc.json`がJSON形式として正しいか確認：

```bash
npx textlint --print-config docs/index.md
```

### コマンドラインでエラーが検出されるが、VS Codeでは表示されない

VS Code拡張は、コマンドラインとは別のプロセスで動作する。以下を確認すること：

1. VS Codeを再起動
2. ワークスペースフォルダーが正しく開かれているか確認
3. `textlint.trace.server: "verbose"` でログを確認

### 特定のルールを一時的に無効化したい

ファイル内でコメントを使ってルールを無効化できる：

```markdown
<!-- textlint-disable -->
ここはチェックされません。
<!-- textlint-enable -->
```

特定のルールのみ無効化：

```markdown
<!-- textlint-disable prh -->
エディタ（長音符号なし）
<!-- textlint-enable prh -->
```

### 除外ファイルを設定したい

`.textlintignore`ファイルに除外パターンを記述：

```
# システム設定ファイル
CLAUDE.md
AGENTS.md
```

## ルールのカスタマイズ

`.textlintrc.json`を編集することで、ルールをカスタマイズできる。

### ルールを無効化

```json
{
  "rules": {
    "no-mix-dearu-desumasu": false
  }
}
```

### ルールのオプションを変更

```json
{
  "rules": {
    "preset-japanese": {
      "sentence-length": { "max": 200 }
    }
  }
}
```

## 参考リンク

- [textlint公式サイト](https://textlint.github.io/)
- [textlint-rule-preset-japanese](https://github.com/textlint-ja/textlint-rule-preset-japanese)
- [textlint-rule-preset-jtf-style](https://github.com/textlint-ja/textlint-rule-preset-JTF-style)
- [textlint-rule-preset-icsmedia](https://github.com/ics-creative/textlint-rule-preset-icsmedia)
- [VS Code textlint拡張](https://marketplace.visualstudio.com/items?itemName=3w36zj6.textlint)
