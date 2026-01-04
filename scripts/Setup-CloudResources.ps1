#requires -Version 7.0
[CmdletBinding()]
# スクリプトの実行パラメーター
param(
    [string] $Owner,                        # GitHubオーナー名（orgまたはuser）未指定時はgit upstreamから推定
    [string] $Repository,                   # GitHubリポジトリ名 未指定時はgit upstreamから推定
    [int] $PropagationDelaySeconds = 15,    # AAD伝播待ち秒数
    [int] $PropagationRetryCount = 5,       # AAD伝播待ちの最大リトライ回数
    [switch] $Force,                        # 既存RGがある場合に削除して進む
    [scriptblock] $AzInvoker,               # az CLI呼び出しを差し替える場合に指定
    [scriptblock] $GhInvoker,               # gh CLI呼び出しを差し替える場合に指定
    [scriptblock] $ReadHostInvoker          # Read-Host呼び出しを差し替える場合に指定
)

function Invoke-SetupAzureResources {
    [CmdletBinding()]
    param(
        [string] $Owner,
        [string] $Repository,

        [int] $PropagationDelaySeconds = 15, # AAD伝播待ち秒数
        [int] $PropagationRetryCount = 5,    # AAD伝播待ちの最大リトライ回数
        [switch] $Force,                     # 既存RGがある場合に削除して進む

        [scriptblock] $AzInvoker,       # az CLI呼び出しを差し替える場合に指定
        [scriptblock] $GhInvoker,       # gh CLI呼び出しを差し替える場合に指定
        [scriptblock] $ReadHostInvoker  # Read-Host呼び出しを差し替える場合に指定
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

    if (-not $ReadHostInvoker) {
        $ReadHostInvoker = {
            param([string] $Prompt)
            Read-Host -Prompt $Prompt
        }
    }

    $invokeAz = { & $AzInvoker @args }
    $invokeGh = { & $GhInvoker @args }
    $invokeReadHost = { param([string] $Prompt) & $ReadHostInvoker $Prompt }

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

    # リソースグループの存在確認と作成
    Write-Host '[1/7] Checking Resource Group...'
    $rgExistsRaw = & $invokeAz group exists --name $resourceGroupName
    $rgExists = $rgExistsRaw.ToString().Trim().ToLowerInvariant() -eq 'true'

    if ($rgExists) {
        if ($Force) {
            Write-Host "  Resource Group already exists. Deleting: $resourceGroupName"
            & $invokeAz group delete --name $resourceGroupName --yes --no-wait
            & $invokeAz group wait --name $resourceGroupName --deleted
            & $invokeAz group create --name $resourceGroupName --location $location -o none
            Write-Host "  Created: $resourceGroupName"
        } else {
            Write-Host "  Already exists: $resourceGroupName (skipped)"
        }
    } else {
        & $invokeAz group create --name $resourceGroupName --location $location -o none
        Write-Host "  Created: $resourceGroupName"
    }

    # Static Web Apps の作成とホスト名取得
    Write-Host '[2/7] Checking Static Web App...'
    $defaultHostname = $null
    try {
        $defaultHostname = & $invokeAz staticwebapp show --name $swaName --resource-group $resourceGroupName --query defaultHostname -o tsv 2>$null
    } catch {
        # SWAが存在しない
    }

    if ($defaultHostname) {
        Write-Host "  Already exists: $swaName (skipped)"
        Write-Host "  Hostname: $defaultHostname"
    } else {
        & $invokeAz staticwebapp create --name $swaName --resource-group $resourceGroupName --location $swaLocation --sku Standard -o none
        $defaultHostname = & $invokeAz staticwebapp show --name $swaName --resource-group $resourceGroupName --query defaultHostname -o tsv
        Write-Host "  Created: $swaName"
        Write-Host "  Hostname: $defaultHostname"
    }

    # マネージドID作成とID情報の取得
    Write-Host '[3/7] Checking Managed Identity...'
    $clientId = $null
    try {
        $clientId = & $invokeAz identity show --name $identityName --resource-group $resourceGroupName --query clientId -o tsv 2>$null
    } catch {
        # Identityが存在しない
    }

    if ($clientId) {
        $principalId = & $invokeAz identity show --name $identityName --resource-group $resourceGroupName --query principalId -o tsv
        Write-Host "  Already exists: $identityName (skipped)"
        Write-Host "  Client ID: $clientId"
    } else {
        & $invokeAz identity create --name $identityName --resource-group $resourceGroupName --location $location -o none
        $clientId = & $invokeAz identity show --name $identityName --resource-group $resourceGroupName --query clientId -o tsv
        $principalId = & $invokeAz identity show --name $identityName --resource-group $resourceGroupName --query principalId -o tsv
        Write-Host "  Created: $identityName"
        Write-Host "  Client ID: $clientId"
    }

    # OIDCフェデレーション資格情報の作成
    Write-Host '[4/7] Checking Federated Credential...'
    $fcExists = $false
    try {
        & $invokeAz identity federated-credential show --name $federatedCredentialName --identity-name $identityName --resource-group $resourceGroupName -o none 2>$null
        $fcExists = $true
    } catch {
        # Credentialが存在しない
    }

    if ($fcExists) {
        Write-Host "  Already exists: $federatedCredentialName (skipped)"
    } else {
        & $invokeAz identity federated-credential create --name $federatedCredentialName --identity-name $identityName --resource-group $resourceGroupName --issuer 'https://token.actions.githubusercontent.com' --subject "repo:${githubRepo}:ref:refs/heads/main" --audiences 'api://AzureADTokenExchange' -o none
        Write-Host "  Created: $federatedCredentialName"
    }

    # RBAC割り当て（伝播完了までリトライしContributor付与）
    Write-Host '[5/7] Checking RBAC role assignment...'
    $swaId = & $invokeAz staticwebapp show --name $swaName --resource-group $resourceGroupName --query id -o tsv

    # 既存のロール割り当てを確認
    $roleAssignmentExists = $false
    try {
        $assignments = & $invokeAz role assignment list --assignee $principalId --scope $swaId --role 'Contributor' -o json 2>$null
        if ($assignments -and ($assignments | ConvertFrom-Json).Count -gt 0) {
            $roleAssignmentExists = $true
        }
    } catch {
        # 割り当てが存在しない
    }

    if ($roleAssignmentExists) {
        Write-Host "  Already assigned: Contributor role to $identityName (skipped)"
    } else {
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
    }

    # GitHub Discussions 設定
    Write-Host '[6/7] Checking GitHub Discussions...'
    & $invokeGh repo edit $githubRepo --enable-discussions
    Write-Host "  Enabled Discussions for $githubRepo"

    # カテゴリー存在確認用の関数
    $checkCategory = {
        $categoryQuery = "query { repository(owner: `"$Owner`", name: `"$Repository`") { discussionCategory(slug: `"invitation`") { id } } }"
        try {
            $result = & $invokeGh api graphql -f "query=$categoryQuery" 2>&1 | ConvertFrom-Json
            return $null -ne $result.data.repository.discussionCategory
        } catch {
            return $false
        }
    }

    # 既に存在すればスキップ
    if (& $checkCategory) {
        Write-Host '  Invitation category already exists (skipped)'
    } else {
        # 存在しない場合はループで案内
        while ($true) {
            Write-Host ''
            Write-Host '=== GitHub Discussions Setup ==='
            Write-Host 'Discussionカテゴリー "Invitation" を作成してください。'
            Write-Host ''
            Write-Host '手順:'
            Write-Host '1. GitHub → Settings → Discussions'
            Write-Host '2. Set up discussions をクリック（初回のみ）'
            Write-Host '3. Categories → New category をクリック'
            Write-Host '4. Name: Invitation'
            Write-Host '5. Description: SWA role sync invitations'
            Write-Host '6. Discussion Format: Announcement'
            Write-Host '7. Create category をクリック'
            Write-Host ''
            $null = & $invokeReadHost 'カテゴリー作成後、Enterを押してください'

            # 再確認
            if (& $checkCategory) {
                Write-Host '  ✓ Invitation category verified'
                break
            }
            Write-Host '  Invitationカテゴリーが見つかりません。再度作成してください。'
        }
    }

    # GitHub Actions 用シークレット登録
    Write-Host '[7/7] Checking GitHub Secrets...'

    # 既存シークレットのチェック
    $existingSecretsJson = & $invokeGh secret list --repo $githubRepo --json name
    $existingSecrets = @()
    if ($existingSecretsJson) {
        $parsed = $existingSecretsJson | ConvertFrom-Json
        if ($parsed) {
            $existingSecrets = @($parsed | ForEach-Object { $_.name })
        }
    }

    # 必要なシークレット一覧
    $requiredSecrets = @('AZURE_CLIENT_ID', 'AZURE_TENANT_ID', 'AZURE_SUBSCRIPTION_ID', 'AZURE_STATIC_WEB_APPS_API_TOKEN', 'ROLE_SYNC_APP_ID', 'ROLE_SYNC_APP_PRIVATE_KEY')
    $allSecretsExist = $true
    foreach ($secret in $requiredSecrets) {
        if ($secret -notin $existingSecrets) {
            $allSecretsExist = $false
            break
        }
    }

    if ($allSecretsExist -and -not $Force) {
        Write-Host "  All secrets already exist (skipped)"
    } else {
        if ($Force -and $existingSecrets.Count -gt 0) {
            Write-Host "  Overwriting existing secrets with -Force..."
        }

        $tenantId = & $invokeAz account show --query tenantId -o tsv
        $subscriptionId = & $invokeAz account show --query id -o tsv
        $staticWebAppsApiToken = & $invokeAz staticwebapp secrets list --name $swaName --resource-group $resourceGroupName --query properties.apiKey -o tsv

        & $invokeGh secret set AZURE_CLIENT_ID --body $clientId --repo $githubRepo | Out-Null
        & $invokeGh secret set AZURE_TENANT_ID --body $tenantId --repo $githubRepo | Out-Null
        & $invokeGh secret set AZURE_SUBSCRIPTION_ID --body $subscriptionId --repo $githubRepo | Out-Null
        & $invokeGh secret set AZURE_STATIC_WEB_APPS_API_TOKEN --body $staticWebAppsApiToken --repo $githubRepo | Out-Null

        Write-Host "  ✓ Set Actions secret AZURE_CLIENT_ID: $clientId"
        Write-Host "  ✓ Set Actions secret AZURE_TENANT_ID: $tenantId"
        Write-Host "  ✓ Set Actions secret AZURE_SUBSCRIPTION_ID: $subscriptionId"
        Write-Host '  ✓ Set Actions secret AZURE_STATIC_WEB_APPS_API_TOKEN: (redacted)'

        # GitHub Apps 関連シークレットの対話入力
        Write-Host ''
        Write-Host '=== GitHub App Setup ==='
        Write-Host 'GitHub Appを作成し、以下の情報を入力してください。'
        Write-Host ''
        Write-Host '手順:'
        Write-Host '1. GitHub → Settings → Developer settings → GitHub Apps → New GitHub App'
        Write-Host '2. App name: 任意（例: role-sync-app）'
        Write-Host '3. Homepage URL: リポジトリのURL'
        Write-Host '4. Webhook: Active のチェックを外す'
        Write-Host '5. Permissions → Repository → Discussions: Read and write'
        Write-Host '6. Create GitHub App をクリック'
        Write-Host '7. 作成後、App ID をコピー'
        Write-Host '8. Private keys → Generate a private key でPEMファイルをダウンロード'
        Write-Host ''

        $appId = & $invokeReadHost 'GitHub App ID を入力してください'
        $privateKeyPath = & $invokeReadHost 'Private Key ファイルのパスを入力してください'
        $privateKey = Get-Content -Path $privateKeyPath -Raw

        & $invokeGh secret set ROLE_SYNC_APP_ID --body $appId --repo $githubRepo | Out-Null
        & $invokeGh secret set ROLE_SYNC_APP_PRIVATE_KEY --body $privateKey --repo $githubRepo | Out-Null

        Write-Host "  ✓ Set Actions secret ROLE_SYNC_APP_ID: $appId"
        Write-Host '  ✓ Set Actions secret ROLE_SYNC_APP_PRIVATE_KEY: (redacted)'
    }

    Write-Host ''
    Write-Host '=== Setup Complete ==='
    Write-Host "SWA URL: https://$defaultHostname"
}

if ($MyInvocation.InvocationName -notin @('.', 'source')) {
    Invoke-SetupAzureResources @PSBoundParameters
}
