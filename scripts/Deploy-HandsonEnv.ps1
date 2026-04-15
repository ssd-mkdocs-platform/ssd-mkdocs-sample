<#
.SYNOPSIS
    ハンズオン環境を Azure 上にデプロイする。

.DESCRIPTION
    settings.local.json の設定をもとに、以下を実行する。
    1. リソースグループの作成
    2. 共有インフラのデプロイ（ACR, Managed Identity, Log Analytics, Container Apps Environment）
    3. ハンズオン用コンテナイメージのビルド・プッシュ
    4. 参加者ごとの Container App デプロイ
    5. 参加者情報（URL・パスワード）の出力

.PARAMETER UserCount
    参加者数。この数だけ Container App をデプロイする。

.PARAMETER ImageTag
    コンテナイメージのタグ。省略時は現在の Git コミットハッシュ（短縮形）を使用する。

.PARAMETER SkipImageBuild
    イメージのビルド・プッシュをスキップする。既にイメージが ACR に存在する場合に使用する。

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
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $repoRoot "handson-deploy-$timestamp.log"
Start-Transcript -Path $logPath

$settingsPath = Join-Path $repoRoot 'settings.local.json'

# ---------- 設定読み込み ----------
if (-not (Test-Path $settingsPath)) {
    Write-Error "設定ファイルが見つかりません: $settingsPath"
}
$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

# ImageTag 省略時は Git コミットハッシュを使用
if (-not $ImageTag) {
    $ImageTag = git -C $repoRoot rev-parse --short HEAD
    Write-Host "ImageTag を Git コミットハッシュから自動取得: $ImageTag"
}

Write-Host ''
Write-Host '========================================='
Write-Host '  ハンズオン環境デプロイ'
Write-Host '========================================='
Write-Host "  サブスクリプション : $($settings.subscriptionId)"
Write-Host "  リソースグループ   : $($settings.resourceGroup)"
Write-Host "  リージョン         : $($settings.location)"
Write-Host "  参加者数           : $UserCount"
Write-Host "  イメージタグ       : $ImageTag"
Write-Host '========================================='
Write-Host ''

# ---------- サブスクリプション設定 ----------
Write-Host '[1/5] サブスクリプションを設定中...'
az account set --subscription $settings.subscriptionId

# ---------- リソースグループ作成 ----------
Write-Host '[2/5] リソースグループを作成中...'
az group create `
    --name $settings.resourceGroup `
    --location $settings.location `
    --output none

# ---------- 共有インフラデプロイ ----------
Write-Host '[3/5] 共有インフラをデプロイ中（ACR, Managed Identity, Log Analytics, Container Apps Environment）...'
$infraResult = az deployment group create `
    --resource-group $settings.resourceGroup `
    --template-file (Join-Path $repoRoot 'infra/main.bicep') `
    --parameters location=$($settings.location) `
    --query 'properties.outputs' `
    --output json | ConvertFrom-Json

$acrName = $infraResult.acrName.value
$acrLoginServer = $infraResult.acrLoginServer.value
$environmentId = $infraResult.environmentId.value
$identityId = $infraResult.identityId.value

Write-Host "  ACR:         $acrLoginServer"
Write-Host "  Environment: $environmentId"

# ---------- イメージビルド ----------
if ($SkipImageBuild) {
    Write-Host '[4/5] イメージビルドをスキップ'
} else {
    Write-Host "[4/5] イメージをビルド・プッシュ中 (handson-env:$ImageTag)..."
    az acr build `
        --registry $acrName `
        --image "handson-env:${ImageTag}" `
        --file (Join-Path $repoRoot 'infra/Dockerfile.handson') `
        $repoRoot
}

# ---------- 参加者ごとの Container App デプロイ ----------
Write-Host "[5/5] Container App を $UserCount 台デプロイ中..."

$credentials = @()
for ($i = 1; $i -le $UserCount; $i++) {
    $userName = 'user-{0:D2}' -f $i
    $password = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 12 | ForEach-Object { [char]$_ })

    Write-Host "  デプロイ中: handson-$userName ($i/$UserCount)"

    $appResult = az deployment group create `
        --resource-group $settings.resourceGroup `
        --template-file (Join-Path $repoRoot 'infra/container-app.bicep') `
        --parameters `
            location=$($settings.location) `
            environmentId=$environmentId `
            acrLoginServer=$acrLoginServer `
            identityId=$identityId `
            imageName='handson-env' `
            imageTag=$ImageTag `
            userName=$userName `
            password=$password `
        --query 'properties.outputs' `
        --output json | ConvertFrom-Json

    $credentials += [PSCustomObject]@{
        User     = $userName
        URL      = "https://$($appResult.fqdn.value)"
        Password = $password
    }
}

# ---------- 結果出力 ----------
Write-Host ''
Write-Host '========================================='
Write-Host '  デプロイ完了 - 参加者情報'
Write-Host '========================================='
$credentials | Format-Table -AutoSize

$credentialsPath = Join-Path $repoRoot 'handson-credentials.json'
$credentials | ConvertTo-Json -Depth 2 | Out-File -FilePath $credentialsPath -Encoding utf8
Write-Host "参加者情報を出力しました: $credentialsPath"

Stop-Transcript
