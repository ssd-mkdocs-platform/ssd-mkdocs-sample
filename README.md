# 仕様駆動開発時代のドキュメント基盤

MkDocs + Material for MkDocsを使用したドキュメント基盤です。Mermaidによる図表作成、WeasyPrintによるPDF生成をサポートしています。

## 技術スタック

| 技術 | 用途 |
|------|------|
| MkDocs + Material for MkDocs | 静的サイトジェネレーター |
| Mermaid | Markdown内での図表作成 |
| Draw.io | SVG図表（PNG変換） |
| WeasyPrint | PDF生成 |
| Playwright | Mermaidレンダリング用ブラウザ自動化 |
| Pester | PowerShellスクリプトのテスト |

## 必要環境

- Windows OS
- 管理者権限（初回セットアップ時）

## 環境構築

管理者としてPowerShellを開き、以下を実行します：

```powershell
.\scripts\Setup-Environments.ps1
```

このスクリプトは以下をインストールします：

- Python 3.13
- uv（Pythonパッケージマネージャー）
- Node.js
- Mermaid CLI
- GTK+ Runtime（PDF生成用）
- プロジェクト依存パッケージ

## 日常の利用方法

```powershell
# ローカルプレビュー（http://127.0.0.1:8000 でライブリロード）
uv run mkdocs serve

# 本番ビルド
uv run mkdocs build

# PDF生成（GTK Runtimeが必要）
$env:MKDOCS_PDF=1; uv run mkdocs build
```

## テスト

PowerShellスクリプトのテストにはPesterを使用します。

```powershell
# 全テスト実行（カバレッジ付き）
./scripts/tests/Run-AllTests.ps1

# 単一テストファイルの実行
Invoke-Pester -Path ./scripts/tests/Setup-Environments.Tests.ps1
```

## CI/CD

GitHub Actionsで以下のワークフローが設定されています：

### CI Tests (`ci-tests.yml`)

- **トリガー**: `scripts/**` 配下の変更時（push/PR）
- **実行環境**: Windows
- **内容**: Pesterによるテスト実行

### Deploy Site (`deploy-site.yml`)

- **トリガー**: `docs/**`, `mkdocs.yml`, `pyproject.toml` 等の変更時
- **実行環境**: Ubuntu
- **デプロイ先**:
  - Azure Static Web Apps（全ブランチ）
  - GitHub Pages（mainブランチのみ）
- **PDF生成**: mainブランチへのpush時のみ有効

PRを作成すると、Azure Static Web Appsにプレビュー環境が自動デプロイされます。

## プロジェクト構造

```
.
├── docs/                  # ドキュメントソース（Markdown）
├── scripts/               # PowerShellスクリプト
│   ├── Setup-Environments.ps1  # 環境構築スクリプト
│   └── tests/             # Pesterテスト
├── mkdocs.yml             # MkDocs設定（ナビゲーション、プラグイン）
├── pyproject.toml         # Python依存関係（uv管理）
└── uv.lock                # 依存関係ロックファイル
```
