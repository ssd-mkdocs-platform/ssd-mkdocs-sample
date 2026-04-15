<#
.SYNOPSIS
    ハンズオン環境を Azure 上にデプロイする。

.DESCRIPTION
    settings.local.json の設定をもとに、以下を実行する。
    1. リソースグループの作成
    2. 共有インフラのデプロイ（Log Analytics, Container Apps Environment）
    3. ハンズオン用コンテナイメージのビルド・プッシュ（ghcr.io）
    4. 参加者ごとの Container App デプロイ
    5. 参加者情報（URL・パスワード）の出力

.PARAMETER UserCount
    参加者数。この数だけ Container App をデプロイする。

.PARAMETER ImageTag
    コンテナイメージのタグ。省略時は現在の Git コミットハッシュ（短縮形）を使用する。

.PARAMETER SkipImageBuild
    イメージのビルド・プッシュをスキップする。既にイメージが ghcr.io に存在する場合に使用する。

.EXAMPLE
    .\Deploy-HandsonEnv.ps1 -UserCount 20
    .\Deploy-HandsonEnv.ps1 -UserCount 5 -SkipImageBuild
#>
param(
    [Parameter(Mandatory)]
    [ValidateRange(1, 50)]
    [int]$UserCount,

    [string]$ImageTag,

    [switch]$SkipImageBuild
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $repoRoot 'handson-out'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$timestamp = Get-Date -Format 'yyyyMMddHHmmss'
Start-Transcript -Path (Join-Path $outDir "deploy-$timestamp.log")

$settingsPath = Join-Path $repoRoot 'settings.local.json'

try {

# ---------- 設定読み込み ----------
if (-not (Test-Path $settingsPath)) {
    Write-Error "設定ファイルが見つかりません: $settingsPath"
}
$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

# リソースグループ名: settings の値をプレフィックスとしタイムスタンプを付与
$rgName = "$($settings.resourceGroup)-$timestamp"

# ImageTag 省略時は Git コミットハッシュを使用
if (-not $ImageTag) {
    $ImageTag = git -C $repoRoot rev-parse --short HEAD
    Write-Host "ImageTag を Git コミットハッシュから自動取得: $ImageTag"
}

$ghcrImage = $settings.ghcrImage
$imageRef = "${ghcrImage}:${ImageTag}"

Write-Host ''
Write-Host '========================================='
Write-Host '  ハンズオン環境デプロイ'
Write-Host '========================================='
Write-Host "  サブスクリプション : $($settings.subscriptionId)"
Write-Host "  リソースグループ   : $rgName"
Write-Host "  リージョン         : $($settings.location)"
Write-Host "  参加者数           : $UserCount"
Write-Host "  イメージ           : $imageRef"
Write-Host '========================================='
Write-Host ''

# ---------- サブスクリプション設定 ----------
Write-Host '[1/5] サブスクリプションを設定中...'
az account set --subscription $settings.subscriptionId
if ($LASTEXITCODE -ne 0) { throw "サブスクリプションの設定に失敗しました" }

# ---------- リソースグループ作成 ----------
Write-Host '[2/5] リソースグループを作成中...'
az group create `
    --name $rgName `
    --location $settings.location `
    --output none
if ($LASTEXITCODE -ne 0) { throw "リソースグループの作成に失敗しました" }

# ---------- 共有インフラデプロイ ----------
Write-Host '[3/5] 共有インフラをデプロイ中（Log Analytics, Container Apps Environment）...'
$infraJson = az deployment group create `
    --resource-group $rgName `
    --template-file (Join-Path $repoRoot 'infra/main.bicep') `
    --parameters "location=$($settings.location)" `
    --output json 2>$null
if ($LASTEXITCODE -ne 0) { throw "共有インフラのデプロイに失敗しました" }
$infraOutputs = ($infraJson | ConvertFrom-Json).properties.outputs

$environmentId = $infraOutputs.environmentId.value

Write-Host "  Environment: $environmentId"

# ---------- イメージビルド ----------
if ($SkipImageBuild) {
    Write-Host '[4/5] イメージビルドをスキップ'
} else {
    Write-Host "[4/5] イメージをビルド・プッシュ中 ($imageRef)..."
    docker build -t $imageRef -f (Join-Path $repoRoot 'infra/Dockerfile.handson') $repoRoot
    if ($LASTEXITCODE -ne 0) { throw "イメージのビルドに失敗しました" }
    docker push $imageRef
    if ($LASTEXITCODE -ne 0) { throw "イメージのプッシュに失敗しました" }
}

# ---------- 参加者ごとの Container App デプロイ ----------
Write-Host "[5/5] Container App を $UserCount 台デプロイ中..."

$credentials = @()
for ($i = 1; $i -le $UserCount; $i++) {
    $userName = 'user-{0:D2}' -f $i
    $password = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 12 | ForEach-Object { [char]$_ })

    Write-Host "  デプロイ中: handson-$userName ($i/$UserCount)"

    $deployParams = @(
        "location=$($settings.location)"
        "environmentId=$environmentId"
        "imageRef=$imageRef"
        "userName=$userName"
        "password=$password"
    )
    $appJson = az deployment group create `
        --resource-group $rgName `
        --template-file (Join-Path $repoRoot 'infra/container-app.bicep') `
        --parameters $deployParams `
        --output json 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Container App '$userName' のデプロイに失敗しました" }
    $appOutputs = ($appJson | ConvertFrom-Json).properties.outputs

    $credentials += [PSCustomObject]@{
        User     = $userName
        URL      = "https://$($appOutputs.fqdn.value)"
        Password = $password
    }
}

# ---------- 結果出力 ----------
Write-Host ''
Write-Host '========================================='
Write-Host '  デプロイ完了 - 参加者情報'
Write-Host '========================================='
$credentials | Format-Table -AutoSize

$credentialsPath = Join-Path $outDir "credentials-$timestamp.json"
$credentials | ConvertTo-Json -Depth 2 | Out-File -FilePath $credentialsPath -Encoding utf8
Write-Host "参加者情報を出力しました: $credentialsPath"

} finally {
    Stop-Transcript
}
