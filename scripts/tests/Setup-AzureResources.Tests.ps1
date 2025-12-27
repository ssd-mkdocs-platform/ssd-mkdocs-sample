$ErrorActionPreference = 'Stop'

Describe 'Setup-AzureResources.ps1' {
    BeforeAll {
        $start = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).ProviderPath }
        $current = (Resolve-Path $start).ProviderPath

        while ($true) {
            $candidate = Join-Path -Path $current -ChildPath 'Setup-AzureResources.ps1'
            if (Test-Path $candidate) {
                $scriptPath = (Resolve-Path $candidate).ProviderPath
                break
            }

            $parent = Split-Path -Path $current -Parent
            if (-not $parent -or $parent -eq $current) {
                throw 'Setup-AzureResources.ps1 のパスを解決できません。'
            }
            $current = $parent
        }

        $scriptRoot = Split-Path -Path $scriptPath -Parent
    }

    It '指定したownerとrepositoryでAzureとGitHubの設定を呼び出す' {
        $scriptPath = Join-Path $scriptRoot 'Setup-AzureResources.ps1'
        $owner = 'nuitsjp'
        $repository = 'swa-github-role-sync-ops'
        $defaultHostname = 'example.eastasia.azurestaticapps.net'
        $clientId = 'client-123'
        $principalId = 'principal-456'
        $tenantId = 'tenant-789'
        $subscriptionId = 'sub-000'
        $swaId = "/subscriptions/$subscriptionId/resourceGroups/rg-$repository-prod/providers/Microsoft.Web/staticSites/stapp-$repository-prod"

        $global:SetupAzCalls = @()
        $global:SetupGhCalls = @()
        $global:RoleAssignmentAttempts = 0

        $azInvoker = {
            $global:SetupAzCalls += ,$args

            switch -Wildcard ($args -join ' ') {
                'group exists*' { 'false' }
                '*staticwebapp show*defaultHostname*' { $defaultHostname }
                '*identity show*clientId*' { $clientId }
                '*identity show*principalId*' { $principalId }
                '*staticwebapp show* --query id *' { $swaId }
                '*account show*tenantId*' { $tenantId }
                '*account show* --query id *' { $subscriptionId }
                'role assignment create*' {
                    $global:RoleAssignmentAttempts++
                    if ($global:RoleAssignmentAttempts -lt 2) {
                        throw 'AAD propagation delay'
                    }
                }
            }
        }

        $ghInvoker = {
            $global:SetupGhCalls += ,$args
        }

        $gitInvoker = {
            throw 'git should not be called when Owner/Repository are provided'
        }

        Mock -CommandName Start-Sleep -ParameterFilter { $Seconds -eq 15 }

        & $scriptPath -Owner $owner -Repository $repository -AzInvoker $azInvoker -GhInvoker $ghInvoker -GitInvoker $gitInvoker

        Assert-MockCalled Start-Sleep -ParameterFilter { $Seconds -eq 15 } -Times 1

        $azCallLines = $global:SetupAzCalls | ForEach-Object { $_ -join ' ' }
        $ghCallLines = $global:SetupGhCalls | ForEach-Object { $_ -join ' ' }

        $azCallLines | Should -Contain "group exists --name rg-$repository-prod"
        $azCallLines | Should -Contain "group create --name rg-$repository-prod --location japaneast -o none"
        $azCallLines | Should -Contain "staticwebapp create --name stapp-$repository-prod --resource-group rg-$repository-prod --location eastasia --sku Standard -o none"
        $azCallLines | Should -Contain "staticwebapp show --name stapp-$repository-prod --resource-group rg-$repository-prod --query defaultHostname -o tsv"
        $azCallLines | Should -Contain "identity create --name id-$repository-prod --resource-group rg-$repository-prod --location japaneast -o none"
        $azCallLines | Should -Contain "identity show --name id-$repository-prod --resource-group rg-$repository-prod --query clientId -o tsv"
        $azCallLines | Should -Contain "identity show --name id-$repository-prod --resource-group rg-$repository-prod --query principalId -o tsv"
        $azCallLines | Should -Contain "identity federated-credential create --name fc-github-actions-main --identity-name id-$repository-prod --resource-group rg-$repository-prod --issuer https://token.actions.githubusercontent.com --subject repo:${owner}/${repository}:ref:refs/heads/main --audiences api://AzureADTokenExchange -o none"
        $azCallLines | Should -Contain "staticwebapp show --name stapp-$repository-prod --resource-group rg-$repository-prod --query id -o tsv"
        ($azCallLines | Where-Object { $_ -like 'role assignment create*' }).Count | Should -Be 2
        $azCallLines | Should -Contain 'account show --query tenantId -o tsv'
        $azCallLines | Should -Contain 'account show --query id -o tsv'
        $ghCallLines | Should -Contain "secret set AZURE_CLIENT_ID --body $clientId --repo $owner/$repository"
        $ghCallLines | Should -Contain "secret set AZURE_TENANT_ID --body $tenantId --repo $owner/$repository"
        $ghCallLines | Should -Contain "secret set AZURE_SUBSCRIPTION_ID --body $subscriptionId --repo $owner/$repository"
    }

    It '既存リソースグループがある場合はForceなしならエラーで止まる' {
        $scriptPath = Join-Path $scriptRoot 'Setup-AzureResources.ps1'
        $owner = 'nuitsjp'
        $repository = 'swa-github-role-sync-ops'

        $global:SetupAzCalls = @()

        $azInvoker = {
            $global:SetupAzCalls += ,$args
            switch -Wildcard ($args -join ' ') {
                'group exists*' { 'true' }
            }
        }

        $gitInvoker = {
            throw 'git should not be called when Owner/Repository are provided'
        }

        { & $scriptPath -Owner $owner -Repository $repository -AzInvoker $azInvoker -GitInvoker $gitInvoker } | Should -Throw

        $azCallLines = $global:SetupAzCalls | ForEach-Object { $_ -join ' ' }
        $azCallLines | Should -Contain "group exists --name rg-$repository-prod"
        ($azCallLines | Where-Object { $_ -like 'group delete*' }).Count | Should -Be 0
        ($azCallLines | Where-Object { $_ -like 'group create*' }).Count | Should -Be 0
    }

    It '既存リソースグループがある場合はForce指定で削除してから作成する' {
        $scriptPath = Join-Path $scriptRoot 'Setup-AzureResources.ps1'
        $owner = 'nuitsjp'
        $repository = 'swa-github-role-sync-ops'
        $defaultHostname = 'example.eastasia.azurestaticapps.net'
        $clientId = 'client-123'
        $principalId = 'principal-456'
        $tenantId = 'tenant-789'
        $subscriptionId = 'sub-000'
        $swaId = "/subscriptions/$subscriptionId/resourceGroups/rg-$repository-prod/providers/Microsoft.Web/staticSites/stapp-$repository-prod"

        $global:SetupAzCalls = @()
        $global:SetupGhCalls = @()
        $global:RoleAssignmentAttempts = 0
        $global:GroupDeleteAttempts = 0
        $global:GroupWaitAttempts = 0

        $azInvoker = {
            $global:SetupAzCalls += ,$args

            switch -Wildcard ($args -join ' ') {
                'group exists*' { 'true' }
                'group delete*' { $global:GroupDeleteAttempts++ }
                'group wait* --deleted*' { $global:GroupWaitAttempts++ }
                '*staticwebapp show*defaultHostname*' { $defaultHostname }
                '*identity show*clientId*' { $clientId }
                '*identity show*principalId*' { $principalId }
                '*staticwebapp show* --query id *' { $swaId }
                '*account show*tenantId*' { $tenantId }
                '*account show* --query id *' { $subscriptionId }
                'role assignment create*' {
                    $global:RoleAssignmentAttempts++
                    if ($global:RoleAssignmentAttempts -lt 2) {
                        throw 'AAD propagation delay'
                    }
                }
            }
        }

        $ghInvoker = {
            $global:SetupGhCalls += ,$args
        }

        $gitInvoker = {
            throw 'git should not be called when Owner/Repository are provided'
        }

        Mock -CommandName Start-Sleep -ParameterFilter { $Seconds -eq 15 }

        & $scriptPath -Owner $owner -Repository $repository -AzInvoker $azInvoker -GhInvoker $ghInvoker -GitInvoker $gitInvoker -Force

        Assert-MockCalled Start-Sleep -ParameterFilter { $Seconds -eq 15 } -Times 1

        $azCallLines = $global:SetupAzCalls | ForEach-Object { $_ -join ' ' }
        $ghCallLines = $global:SetupGhCalls | ForEach-Object { $_ -join ' ' }

        $azCallLines | Should -Contain "group exists --name rg-$repository-prod"
        $azCallLines | Should -Contain "group delete --name rg-$repository-prod --yes --no-wait"
        $azCallLines | Should -Contain "group wait --name rg-$repository-prod --deleted"
        ($azCallLines | Where-Object { $_ -like 'group create*' }).Count | Should -Be 1
        ($azCallLines | Where-Object { $_ -like 'role assignment create*' }).Count | Should -Be 2
        $global:GroupDeleteAttempts | Should -Be 1
        $global:GroupWaitAttempts | Should -Be 1
        $ghCallLines | Should -Contain "secret set AZURE_CLIENT_ID --body $clientId --repo $owner/$repository"
    }

    It 'Owner/Repository未指定ならgit upstreamから自動判定する' {
        $scriptPath = Join-Path $scriptRoot 'Setup-AzureResources.ps1'
        $defaultHostname = 'example.eastasia.azurestaticapps.net'
        $clientId = 'client-123'
        $principalId = 'principal-456'
        $tenantId = 'tenant-789'
        $subscriptionId = 'sub-000'
        $swaId = "/subscriptions/$subscriptionId/resourceGroups/rg-swa-github-role-sync-ops-prod/providers/Microsoft.Web/staticSites/stapp-swa-github-role-sync-ops-prod"

        $global:SetupAzCalls = @()
        $global:SetupGhCalls = @()
        $global:RoleAssignmentAttempts = 0
        $global:GitCalls = @()

        $azInvoker = {
            $global:SetupAzCalls += ,$args

            switch -Wildcard ($args -join ' ') {
                'group exists*' { 'false' }
                '*staticwebapp show*defaultHostname*' { $defaultHostname }
                '*identity show*clientId*' { $clientId }
                '*identity show*principalId*' { $principalId }
                '*staticwebapp show* --query id *' { $swaId }
                '*account show*tenantId*' { $tenantId }
                '*account show* --query id *' { $subscriptionId }
                'role assignment create*' {
                    $global:RoleAssignmentAttempts++
                    if ($global:RoleAssignmentAttempts -lt 2) {
                        throw 'AAD propagation delay'
                    }
                }
            }
        }

        $ghInvoker = {
            $global:SetupGhCalls += ,$args
        }

        $gitInvoker = {
            $global:GitCalls += ,$args
            if (($args -join ' ') -eq 'remote get-url upstream') {
                'https://github.com/nuitsjp/swa-github-role-sync-ops.git'
            }
        }

        Mock -CommandName Start-Sleep -ParameterFilter { $Seconds -eq 15 }

        & $scriptPath -AzInvoker $azInvoker -GhInvoker $ghInvoker -GitInvoker $gitInvoker

        $azCallLines = $global:SetupAzCalls | ForEach-Object { $_ -join ' ' }
        $ghCallLines = $global:SetupGhCalls | ForEach-Object { $_ -join ' ' }

        $global:GitCalls | ForEach-Object { $_ -join ' ' } | Should -Contain 'remote get-url upstream'
        $azCallLines | Should -Contain "group exists --name rg-swa-github-role-sync-ops-prod"
        $azCallLines | Should -Contain "staticwebapp create --name stapp-swa-github-role-sync-ops-prod --resource-group rg-swa-github-role-sync-ops-prod --location eastasia --sku Standard -o none"
        $ghCallLines | Should -Contain "secret set AZURE_CLIENT_ID --body $clientId --repo nuitsjp/swa-github-role-sync-ops"
    }
}
