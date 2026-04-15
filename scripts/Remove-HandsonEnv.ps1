<#
.SYNOPSIS
    ハンズオン環境を削除する。

.DESCRIPTION
    settings.local.json の resourceGroup をプレフィックスとして前方一致でリソースグループを検索し、削除する。
    該当が1つならそのまま削除、複数なら選択式で削除する。
    -All を指定すると、該当する全リソースグループを一括削除する。

.PARAMETER All
    前方一致する全リソースグループを一括削除する。

.EXAMPLE
    .\Remove-HandsonEnv.ps1
    .\Remove-HandsonEnv.ps1 -All
#>
param(
    [switch]$All
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $repoRoot 'handson-out'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$timestamp = Get-Date -Format 'yyyyMMddHHmmss'
Start-Transcript -Path (Join-Path $outDir "remove-$timestamp.log")

$settingsPath = Join-Path $repoRoot 'settings.local.json'

try {

if (-not (Test-Path $settingsPath)) {
    Write-Error "設定ファイルが見つかりません: $settingsPath"
}
$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

az account set --subscription $settings.subscriptionId
if ($LASTEXITCODE -ne 0) { throw "サブスクリプションの設定に失敗しました" }

# ---------- 前方一致でリソースグループを検索 ----------
$prefix = $settings.resourceGroup
Write-Host "プレフィックス '$prefix' でリソースグループを検索中..."

$groups = az group list `
    --query "[?starts_with(name, '$prefix')].{name:name, location:location}" `
    --output json 2>$null | ConvertFrom-Json

if ($groups.Count -eq 0) {
    Write-Host '該当するリソースグループがありません。'
    return
}

Write-Host "該当: $($groups.Count) 件"
Write-Host ''

# ---------- 削除対象の決定 ----------
if ($All) {
    $targets = $groups
} elseif ($groups.Count -eq 1) {
    $targets = $groups
} else {
    for ($i = 0; $i -lt $groups.Count; $i++) {
        Write-Host "  [$($i + 1)] $($groups[$i].name)"
    }
    Write-Host ''
    $selection = Read-Host '削除するリソースグループの番号を入力してください'
    $index = [int]$selection - 1
    if ($index -lt 0 -or $index -ge $groups.Count) {
        Write-Error "無効な番号です: $selection"
    }
    $targets = @($groups[$index])
}

# ---------- 削除実行 ----------
foreach ($target in $targets) {
    Write-Host "リソースグループ '$($target.name)' を削除中..."
    az group delete --name $target.name --yes --no-wait
    if ($LASTEXITCODE -ne 0) { throw "リソースグループ '$($target.name)' の削除に失敗しました" }
    Write-Host "  削除を開始しました（バックグラウンド実行）: $($target.name)"
}

Write-Host ''
Write-Host '削除処理を開始しました。完了まで数分かかる場合があります。'

} finally {
    Stop-Transcript
}
