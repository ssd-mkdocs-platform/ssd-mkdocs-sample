#requires -Version 7.0
[CmdletBinding()]
# スクリプトの実行パラメーター
param(
    [string] $Owner,            # GitHubオーナー名（orgまたはuser）未指定時はgit upstreamから推定

    [string] $Repository,       # GitHubリポジトリ名 未指定時はgit upstreamから推定

    [int] $PropagationDelaySeconds = 15, # AAD伝播待ち秒数
    [int] $PropagationRetryCount = 5,    # AAD伝播待ちの最大リトライ回数
    [switch] $Force,                         # 既存RGがある場合に削除して進む

    [scriptblock] $AzInvoker,   # az CLI呼び出しを差し替える場合に指定

    [scriptblock] $GhInvoker   # gh CLI呼び出しを差し替える場合に指定
)

function Invoke-SetupAzureResources {
    [CmdletBinding()]
    param(
        [string] $Owner,
        [string] $Repository,

        [int] $PropagationDelaySeconds = 15, # AAD伝播待ち秒数
        [int] $PropagationRetryCount = 5,    # AAD伝播待ちの最大リトライ回数
        [switch] $Force,                     # 既存RGがある場合に削除して進む

        [scriptblock] $AzInvoker,   # az CLI呼び出しを差し替える場合に指定

        [scriptblock] $GhInvoker   # gh CLI呼び出しを差し替える場合に指定
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

    $invokeAz = { & $AzInvoker @args }
    $invokeGh = { & $GhInvoker @args }

    $resolveRepo = {
        param(
            [string] $OwnerParam,
            [string] $RepositoryParam
        )

        if ($OwnerParam -and $RepositoryParam) {
            return @{ Owner = $OwnerParam; Repository = $RepositoryParam }
        }

        $ghResultRaw = & $invokeGh repo view --json 'owner,name'
        $ghResult = $ghResultRaw | ConvertFrom-Json

        $resolvedOwner = if ($OwnerParam) { $OwnerParam } else { $ghResult.owner.login }
        $resolvedRepo = if ($RepositoryParam) { $RepositoryParam } else { $ghResult.name }

        if (-not $resolvedOwner -or -not $resolvedRepo) {
            throw 'gh repo view で Owner/Repository を解決できませんでした。Owner/Repository を指定してください。'
        }

        return @{ Owner = $resolvedOwner; Repository = $resolvedRepo }
    }

    # リポジトリとデプロイ先リージョンの設定
    $resolved = & $resolveRepo $Owner $Repository
    $Owner = $resolved.Owner
    $Repository = $resolved.Repository
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

    # リソースグループの存在確認と作成（Force時のみ削除して再作成）
    Write-Host '[1/6] Creating Resource Group...'
    $rgExistsRaw = & $invokeAz group exists --name $resourceGroupName
    $rgExists = $rgExistsRaw.ToString().Trim().ToLowerInvariant() -eq 'true'

    if ($rgExists) {
        if (-not $Force) {
            throw "Resource Group $resourceGroupName already exists. Specify -Force to delete and recreate."
        }

        Write-Host "  Resource Group already exists. Deleting: $resourceGroupName"
        & $invokeAz group delete --name $resourceGroupName --yes --no-wait
        & $invokeAz group wait --name $resourceGroupName --deleted
    }
    & $invokeAz group create --name $resourceGroupName --location $location -o none
    Write-Host "  Created: $resourceGroupName"

    # Static Web Apps の作成とホスト名取得
    Write-Host '[2/6] Creating Static Web App...'
    & $invokeAz staticwebapp create --name $swaName --resource-group $resourceGroupName --location $swaLocation --sku Standard -o none
    $defaultHostname = & $invokeAz staticwebapp show --name $swaName --resource-group $resourceGroupName --query defaultHostname -o tsv
    Write-Host "  Created: $swaName"
    Write-Host "  Hostname: $defaultHostname"

    # マネージドID作成とID情報の取得
    Write-Host '[3/6] Creating Managed Identity...'
    & $invokeAz identity create --name $identityName --resource-group $resourceGroupName --location $location -o none
    $clientId = & $invokeAz identity show --name $identityName --resource-group $resourceGroupName --query clientId -o tsv
    $principalId = & $invokeAz identity show --name $identityName --resource-group $resourceGroupName --query principalId -o tsv
    Write-Host "  Created: $identityName"
    Write-Host "  Client ID: $clientId"

    # OIDCフェデレーション資格情報の作成
    Write-Host '[4/6] Creating Federated Credential...'
    & $invokeAz identity federated-credential create --name $federatedCredentialName --identity-name $identityName --resource-group $resourceGroupName --issuer 'https://token.actions.githubusercontent.com' --subject "repo:${githubRepo}:ref:refs/heads/main" --audiences 'api://AzureADTokenExchange' -o none
    Write-Host "  Created: $federatedCredentialName"

    # RBAC割り当て（伝播完了までリトライしContributor付与）
    Write-Host '[5/6] Assigning RBAC role...'
    $swaId = & $invokeAz staticwebapp show --name $swaName --resource-group $resourceGroupName --query id -o tsv
    for ($i = 1; $i -le $PropagationRetryCount; $i++) {
        try {
            & $invokeAz role assignment create --assignee-object-id $principalId --assignee-principal-type ServicePrincipal --role 'Contributor' --scope $swaId -o none
            break
        } catch {
            if ($i -eq $PropagationRetryCount) {
                throw
            }
            Start-Sleep -Seconds $PropagationDelaySeconds # propagation not yet completed
        }
    }
    Write-Host "  Assigned Contributor role to $identityName"

    # GitHub Actions 用シークレット登録
    Write-Host '[6/6] Registering GitHub Secrets...'
    $tenantId = & $invokeAz account show --query tenantId -o tsv
    $subscriptionId = & $invokeAz account show --query id -o tsv

    & $invokeGh secret set AZURE_CLIENT_ID --body $clientId --repo $githubRepo
    & $invokeGh secret set AZURE_TENANT_ID --body $tenantId --repo $githubRepo
    & $invokeGh secret set AZURE_SUBSCRIPTION_ID --body $subscriptionId --repo $githubRepo

    Write-Host "  AZURE_CLIENT_ID: $clientId"
    Write-Host "  AZURE_TENANT_ID: $tenantId"
    Write-Host "  AZURE_SUBSCRIPTION_ID: $subscriptionId"

    Write-Host ''
    Write-Host '=== Setup Complete ==='
    Write-Host "SWA URL: https://$defaultHostname"
}

if ($MyInvocation.InvocationName -notin @('.', 'source')) {
    Invoke-SetupAzureResources @PSBoundParameters
}
