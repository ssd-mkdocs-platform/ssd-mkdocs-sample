<#
.SYNOPSIS
    ハンズオン環境を一括削除する。

.DESCRIPTION
    settings.local.json に記載のリソースグループを削除し、全リソースを一括削除する。
    課金を確実に停止するため、ハンズオン終了後に実行する。

.EXAMPLE
    .\Remove-HandsonEnv.ps1
#>
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $repoRoot "handson-remove-$timestamp.log"
Start-Transcript -Path $logPath

$settingsPath = Join-Path $repoRoot 'settings.local.json'

if (-not (Test-Path $settingsPath)) {
    Write-Error "設定ファイルが見つかりません: $settingsPath"
}
$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

Write-Host ''
Write-Host '========================================='
Write-Host '  ハンズオン環境の削除'
Write-Host '========================================='
Write-Host "  リソースグループ: $($settings.resourceGroup)"
Write-Host '========================================='
Write-Host ''

az account set --subscription $settings.subscriptionId

Write-Host "リソースグループ '$($settings.resourceGroup)' を削除中..."
az group delete --name $settings.resourceGroup --yes
Write-Host '削除が完了しました。'

Stop-Transcript
