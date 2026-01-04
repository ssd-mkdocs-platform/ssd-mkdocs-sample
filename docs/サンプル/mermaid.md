---
title: Mermaid
---

# Mermaid

Mermaidはテキストベースで図を記述できるツールである。本プロジェクトでは推奨ツールとして位置づけている。

## 基本的な使い方

Markdownファイル内で、以下のようにコードブロックを記述する。

````markdown
```mermaid
graph TD
    A[開始] --> B[処理]
    B --> C[終了]
```
````

## フローチャート

処理の流れを表現する基本的な図である。

```mermaid
graph TD
    A[ユーザー入力] --> B{入力チェック}
    B -->|有効| C[データ処理]
    B -->|無効| D[エラー表示]
    C --> E[結果表示]
    D --> A
    E --> F[終了]
```

### 記法のポイント

- `graph TD`: 上から下へ流れる図（Top to Down）
- `graph LR`: 左から右へ流れる図（Left to Right）
- `[テキスト]`: 四角形のノード
- `{テキスト}`: ひし形のノード（条件分岐）
- `-->`: 矢印
- `-->|ラベル|`: ラベル付き矢印

## シーケンス図

オブジェクト間のやり取りを時系列で表現する。

```mermaid
sequenceDiagram
    participant C as クライアント
    participant S as サーバー
    participant D as データベース

    C->>S: リクエスト送信
    activate S
    S->>D: クエリ実行
    activate D
    D-->>S: 結果返却
    deactivate D
    S-->>C: レスポンス送信
    deactivate S
```

### 記法のポイント

- `participant`: 参加者を定義
- `->>`: 同期メッセージ
- `-->>`: 応答メッセージ
- `activate/deactivate`: 活性化バーの表示

## 状態遷移図

システムやオブジェクトの状態の変化を表現する。

```mermaid
stateDiagram-v2
    [*] --> 未着手
    未着手 --> 進行中: 作業開始
    進行中 --> レビュー中: レビュー依頼
    レビュー中 --> 進行中: 修正依頼
    レビュー中 --> 完了: 承認
    完了 --> [*]
```

### 記法のポイント

- `[*]`: 開始・終了状態
- `状態名`: 状態を定義
- `-->`: 遷移

## クラス図

クラスの構造と関係を表現する。

```mermaid
classDiagram
    class Document {
        +String title
        +String content
        +Date createdAt
        +save()
        +delete()
    }

    class MarkdownDocument {
        +String frontMatter
        +render()
    }

    class PdfDocument {
        +generate()
    }

    Document <|-- MarkdownDocument
    Document <|-- PdfDocument
```

### 記法のポイント

- `class クラス名`: クラスを定義
- `+`: public
- `-`: private
- `<|--`: 継承関係

## ER図

データベースのエンティティと関係を表現する。

```mermaid
erDiagram
    USER ||--o{ ORDER : places
    ORDER ||--|{ ORDER_ITEM : contains
    PRODUCT ||--o{ ORDER_ITEM : "is ordered in"

    USER {
        int id PK
        string name
        string email
    }

    ORDER {
        int id PK
        int user_id FK
        date ordered_at
    }

    PRODUCT {
        int id PK
        string name
        int price
    }
```

### 記法のポイント

- `||--o{`: 1対多の関係
- `||--|{`: 1対1以上の関係
- `PK`: 主キー
- `FK`: 外部キー

## ガントチャート

プロジェクトのスケジュールを表現する。

```mermaid
gantt
    title プロジェクトスケジュール
    dateFormat YYYY-MM-DD

    section 設計
    要件定義       :done, req, 2024-01-01, 7d
    基本設計       :done, design, after req, 14d

    section 開発
    実装           :active, dev, after design, 30d
    テスト         :test, after dev, 14d

    section リリース
    デプロイ準備   :deploy, after test, 7d
```

## 参考リンク

- [Mermaid公式ドキュメント](https://mermaid.js.org/)
- [Mermaid Live Editor](https://mermaid.live/)
