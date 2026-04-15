<#
.SYNOPSIS
    ハンズオン用コンテナイメージをビルドする。

.DESCRIPTION
    infra/Dockerfile.handson を使用してハンズオン環境のコンテナイメージをビルドする。
    -Push スイッチを指定すると ghcr.io へプッシュも行う。

.PARAMETER ImageTag
    コンテナイメージのタグ。省略時は現在の Git コミットハッシュ（短縮形）を使用する。

.PARAMETER Push
    ビルド後に ghcr.io へプッシュする。

.EXAMPLE
    .\Build-HandsonImage.ps1
    .\Build-HandsonImage.ps1 -ImageTag v1.0
    .\Build-HandsonImage.ps1 -ImageTag v1.0 -Push
#>
param(
    [string]$ImageTag,

    [switch]$Push
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

# ---------- 設定読み込み ----------
$settingsPath = Join-Path $repoRoot 'settings.local.json'
if (-not (Test-Path $settingsPath)) {
    Write-Error "設定ファイルが見つかりません: $settingsPath"
}
$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

# ---------- ImageTag 解決 ----------
if (-not $ImageTag) {
    $ImageTag = git -C $repoRoot rev-parse --short HEAD
    Write-Host "ImageTag を Git コミットハッシュから自動取得: $ImageTag"
}

$ghcrImage = $settings.ghcrImage
$imageRef = "${ghcrImage}:${ImageTag}"

Write-Host ''
Write-Host '========================================='
Write-Host '  ハンズオンイメージビルド'
Write-Host '========================================='
Write-Host "  イメージ : $imageRef"
Write-Host "  プッシュ : $($Push.IsPresent)"
Write-Host '========================================='
Write-Host ''

# ---------- ビルド ----------
Write-Host "イメージをビルド中 ($imageRef)..."
docker build -t $imageRef -f (Join-Path $repoRoot 'infra/Dockerfile.handson') $repoRoot
if ($LASTEXITCODE -ne 0) { throw "イメージのビルドに失敗しました" }
Write-Host "ビルド完了: $imageRef"

# ---------- プッシュ（オプション） ----------
if ($Push) {
    Write-Host "イメージをプッシュ中 ($imageRef)..."
    docker push $imageRef
    if ($LASTEXITCODE -ne 0) { throw "イメージのプッシュに失敗しました" }
    Write-Host "プッシュ完了: $imageRef"
}
