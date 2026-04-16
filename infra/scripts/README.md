# scripts

PowerShell スクリプトの実装とテストに関する指針。

## ディレクトリ構成

```
infra/scripts/
  *.ps1           # プロダクションスクリプト
  tests/
    *.Tests.ps1   # Pester テスト
    Run-AllTests.ps1  # 全テスト一括実行（カバレージ付き）
```

## 実装指針

- 先頭に `$ErrorActionPreference = 'Stop'` を記述する
- 命名は `動詞-名詞.ps1`（PascalCase）に従う
- 外部コマンド・モジュールへの依存は最小限にする

## テスト指針

- テストファイルは `tests/<対象スクリプト名>.Tests.ps1` に配置する
- テストフレームワークは [Pester](https://pester.dev/) を使用する
- 外部依存（Azure CLI、Git など）は `Mock` で差し替える
- `tests/Run-AllTests.ps1` で全テストを一括実行できる

## テスト実行

```powershell
# 全テスト実行（カバレージ付き）
& infra/scripts/tests/Run-AllTests.ps1

# 個別テスト実行
Invoke-Pester infra/scripts/tests/<対象>.Tests.ps1
```

## npm スクリプト

`package.json` にタスクが定義されており、`pnpm run` で呼び出せる。

```shell
pnpm run infra:test
pnpm run infra:build-image -- -ImageTag v1.0.0
pnpm run infra:deploy-handson-env -- -UserCount 20
pnpm run infra:remove-handson-env -- -All
```

`--` 以降の引数は、そのまま PowerShell スクリプトに転送される。
