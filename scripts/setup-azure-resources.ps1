#requires -Version 7.0
[CmdletBinding()]
# スクリプトの実行パラメーター
param(
    [Parameter(Mandatory = $true)]
    [string] $Owner,            # GitHubオーナー名（orgまたはuser）

    [Parameter(Mandatory = $true)]
    [string] $Repository,       # GitHubリポジトリ名

    [int] $PropagationDelaySeconds = 15, # AAD伝播待ち秒数

    [scriptblock] $AzInvoker,   # az CLI呼び出しを差し替える場合に指定

    [scriptblock] $GhInvoker    # gh CLI呼び出しを差し替える場合に指定
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

# デフォルトのCLI呼び出し（テストやドライランで差し替え可能）
if (-not $AzInvoker) {
    $AzInvoker = {
        az @args
    }
}

if (-not $GhInvoker) {
    $GhInvoker = {
        gh @args
    }
}

<#
.SYNOPSIS
az CLI 呼び出しをラップし、差し替え可能にする。
.DESCRIPTION
AzInvoker スクリプトブロック経由で az を実行し、テスト時にモックしやすくする。
#>
function Invoke-AzCli {
    & $AzInvoker @args
}

<#
.SYNOPSIS
GitHub CLI 呼び出しをラップし、差し替え可能にする。
.DESCRIPTION
GhInvoker スクリプトブロック経由で gh を実行し、テスト時にモックしやすくする。
#>
function Invoke-GhCli {
    & $GhInvoker @args
}

# リポジトリとデプロイ先リージョンの設定
$githubRepo = "$Owner/$Repository"
$location = 'japaneast'
$swaLocation = 'eastasia'

# Microsoft Cloud Adoption Framework (CAF) に沿ったプロダクション向けリソース命名
$resourceGroupName = "rg-$Repository-prod"
$swaName = "stapp-$Repository-prod"
$identityName = "id-$Repository-prod"
$federatedCredentialName = 'fc-github-actions-main'

Write-Host "=== Azure Resource Setup for $Repository ==="
Write-Host "Resource Group: $resourceGroupName"
Write-Host "Static Web App: $swaName"
Write-Host "Managed Identity: $identityName"
Write-Host "GitHub Repo: $githubRepo"
Write-Host ''

# リソースグループの作成
Write-Host '[1/6] Creating Resource Group...'
Invoke-AzCli group create --name $resourceGroupName --location $location -o none
Write-Host "  Created: $resourceGroupName"

# Static Web Apps の作成とホスト名取得
Write-Host '[2/6] Creating Static Web App...'
Invoke-AzCli staticwebapp create --name $swaName --resource-group $resourceGroupName --location $swaLocation --sku Standard -o none
$defaultHostname = Invoke-AzCli staticwebapp show --name $swaName --resource-group $resourceGroupName --query defaultHostname -o tsv
Write-Host "  Created: $swaName"
Write-Host "  Hostname: $defaultHostname"

# マネージドID作成とID情報の取得
Write-Host '[3/6] Creating Managed Identity...'
Invoke-AzCli identity create --name $identityName --resource-group $resourceGroupName --location $location -o none
$clientId = Invoke-AzCli identity show --name $identityName --resource-group $resourceGroupName --query clientId -o tsv
$principalId = Invoke-AzCli identity show --name $identityName --resource-group $resourceGroupName --query principalId -o tsv
Write-Host "  Created: $identityName"
Write-Host "  Client ID: $clientId"

# OIDCフェデレーション資格情報の作成
Write-Host '[4/6] Creating Federated Credential...'
Invoke-AzCli identity federated-credential create --name $federatedCredentialName --identity-name $identityName --resource-group $resourceGroupName --issuer 'https://token.actions.githubusercontent.com' --subject "repo:${githubRepo}:ref:refs/heads/main" --audiences 'api://AzureADTokenExchange' -o none
Write-Host "  Created: $federatedCredentialName"

# RBAC割り当て（伝播待ち後にContributor付与）
Write-Host '[5/6] Assigning RBAC role...'
$swaId = Invoke-AzCli staticwebapp show --name $swaName --resource-group $resourceGroupName --query id -o tsv
Start-Sleep -Seconds $PropagationDelaySeconds # wait for identity to propagate
Invoke-AzCli role assignment create --assignee-object-id $principalId --assignee-principal-type ServicePrincipal --role 'Contributor' --scope $swaId -o none
Write-Host "  Assigned Contributor role to $identityName"

# GitHub Actions 用シークレット登録
Write-Host '[6/6] Registering GitHub Secrets...'
$tenantId = Invoke-AzCli account show --query tenantId -o tsv
$subscriptionId = Invoke-AzCli account show --query id -o tsv

Invoke-GhCli secret set AZURE_CLIENT_ID --body $clientId --repo $githubRepo
Invoke-GhCli secret set AZURE_TENANT_ID --body $tenantId --repo $githubRepo
Invoke-GhCli secret set AZURE_SUBSCRIPTION_ID --body $subscriptionId --repo $githubRepo

Write-Host "  AZURE_CLIENT_ID: $clientId"
Write-Host "  AZURE_TENANT_ID: $tenantId"
Write-Host "  AZURE_SUBSCRIPTION_ID: $subscriptionId"

Write-Host ''
Write-Host '=== Setup Complete ==='
Write-Host "SWA URL: https://$defaultHostname"
