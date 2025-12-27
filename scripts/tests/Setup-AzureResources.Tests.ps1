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

        # ログ出力を抑制する
        Mock -CommandName Write-Host {}
    }

    It 'ドットソースしても外部CLIを呼び出さない' {
        $scriptPath = Join-Path $scriptRoot 'Setup-AzureResources.ps1'

        Mock -CommandName az { throw 'az should not be called when dot-sourced' }
        Mock -CommandName gh { throw 'gh should not be called when dot-sourced' }

        { . $scriptPath } | Should -Not -Throw
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

        $ghInvoker = {
            if (($args -join ' ') -like 'repo view*') {
                throw 'gh should not be called when Owner/Repository are provided'
            }
        }

        { & $scriptPath -Owner $owner -Repository $repository -AzInvoker $azInvoker -GhInvoker $ghInvoker } | Should -Throw

        $azCallLines = $global:SetupAzCalls | ForEach-Object { $_ -join ' ' }
        $azCallLines | Should -Contain "group exists --name rg-$repository-prod"
        ($azCallLines | Where-Object { $_ -like 'group delete*' }).Count | Should -Be 0
        ($azCallLines | Where-Object { $_ -like 'group create*' }).Count | Should -Be 0
    }

    It '既存リソースグループがある場合はForce指定で削除してから作成する' {
        $scriptPath = Join-Path $scriptRoot 'Setup-AzureResources.ps1'
        $owner = 'nuitsjp'
        $repository = 'swa-github-role-sync-ops'
        $global:DefaultOwner = $owner
        $global:DefaultRepository = $repository
        $defaultHostname = 'example.eastasia.azurestaticapps.net'
        $clientId = 'client-123'
        $principalId = 'principal-456'
        $tenantId = 'tenant-789'
        $subscriptionId = 'sub-000'
        $apiKey = 'api-key-000'
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
                '*staticwebapp secrets list*' { $apiKey }
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

        $ghInvoker = {
            $global:SetupGhCalls += ,$args
            if (($args -join ' ') -like 'repo view*') {
                throw 'gh repo view should not be called when Owner/Repository are provided'
            }
        }

        Mock -CommandName Start-Sleep -ParameterFilter { $Seconds -eq 15 }

        & $scriptPath -Owner $owner -Repository $repository -AzInvoker $azInvoker -GhInvoker $ghInvoker -Force

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
        $azCallLines | Should -Contain "staticwebapp secrets list --name stapp-$repository-prod --resource-group rg-$repository-prod --query properties.apiKey -o tsv"
        $ghCallLines | Should -Contain "secret set AZURE_STATIC_WEB_APPS_API_TOKEN --body $apiKey --repo $owner/$repository"
    }

    It 'gh repo viewでOwner/Repositoryを解決する' {
        $scriptPath = Join-Path $scriptRoot 'Setup-AzureResources.ps1'
        $defaultHostname = 'example.eastasia.azurestaticapps.net'
        $clientId = 'client-123'
        $principalId = 'principal-456'
        $tenantId = 'tenant-789'
        $subscriptionId = 'sub-000'
        $swaId = "/subscriptions/$subscriptionId/resourceGroups/rg-spec-driven-docs-infra-prod/providers/Microsoft.Web/staticSites/stapp-spec-driven-docs-infra-prod"

        $global:SetupAzCalls = @()
        $global:SetupGhCalls = @()
        $global:RoleAssignmentAttempts = 0

        . $scriptPath

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
                    if ($global:RoleAssignmentAttempts -lt 2) { throw 'AAD propagation delay' }
                }
            }
        }

        $ghInvoker = {
            $global:SetupGhCalls += ,$args
            if (($args -join ' ') -eq 'repo view --json owner,name') {
                return '{ "name": "spec-driven-docs-infra", "owner": { "login": "nuitsjp" } }'
            }
        }

        Mock -CommandName Start-Sleep -ParameterFilter { $Seconds -eq 15 }

        Invoke-SetupAzureResources -AzInvoker $azInvoker -GhInvoker $ghInvoker

        $global:SetupAzCalls | ForEach-Object { $_ -join ' ' } | Should -Contain 'group exists --name rg-spec-driven-docs-infra-prod'
        $global:SetupGhCalls | ForEach-Object { $_ -join ' ' } | Should -Contain 'repo view --json owner,name'
        Assert-MockCalled Start-Sleep -ParameterFilter { $Seconds -eq 15 } -Times 1
    }

    It 'ghが失敗したら例外を投げる' {
        $scriptPath = Join-Path $scriptRoot 'Setup-AzureResources.ps1'
        $global:SetupAzCalls = @()
        $global:SetupGhCalls = @()

        . $scriptPath

        $azInvoker = { throw 'az should not be called when gh fails' }

        $ghInvoker = {
            $global:SetupGhCalls += ,$args
            if (($args -join ' ') -eq 'repo view --json owner,name') {
                throw 'gh error'
            }
        }

        { Invoke-SetupAzureResources -AzInvoker $azInvoker -GhInvoker $ghInvoker } | Should -Throw 'gh error'

        $global:SetupGhCalls | ForEach-Object { $_ -join ' ' } | Should -Contain 'repo view --json owner,name'
    }

    It 'GitHub Secretsの出力はリポジトリ名を含めず値を表示する' {
        $scriptPath = Join-Path $scriptRoot 'Setup-AzureResources.ps1'
        $owner = 'nuitsjp'
        $repository = 'spec-driven-docs-infra'
        $defaultHostname = 'example.eastasia.azurestaticapps.net'
        $clientId = 'client-123'
        $principalId = 'principal-456'
        $tenantId = 'tenant-789'
        $subscriptionId = 'sub-000'
        $apiKey = 'api-key-000'
        $swaId = "/subscriptions/$subscriptionId/resourceGroups/rg-$repository-prod/providers/Microsoft.Web/staticSites/stapp-$repository-prod"

        $global:SetupAzCalls = @()
        $global:SetupGhCalls = @()
        $global:RoleAssignmentAttempts = 0
        $global:WriteHostMessages = @()

        Mock -CommandName Write-Host -MockWith {
            param($Object)
            $global:WriteHostMessages += $Object
        }

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
                '*staticwebapp secrets list*' { $apiKey }
                'role assignment create*' { }
            }
        }

        $ghInvoker = {
            $global:SetupGhCalls += ,$args
        }

        & $scriptPath -Owner $owner -Repository $repository -AzInvoker $azInvoker -GhInvoker $ghInvoker

        $global:WriteHostMessages | Should -Contain "✓ Set Actions secret AZURE_CLIENT_ID: $clientId"
        $global:WriteHostMessages | Should -Contain "✓ Set Actions secret AZURE_TENANT_ID: $tenantId"
        $global:WriteHostMessages | Should -Contain "✓ Set Actions secret AZURE_SUBSCRIPTION_ID: $subscriptionId"
        $global:WriteHostMessages | Should -Contain '✓ Set Actions secret AZURE_STATIC_WEB_APPS_API_TOKEN: (redacted)'
        ($global:WriteHostMessages | Where-Object { $_ -like "*$owner/$repository*" }).Count | Should -Be 0
    }

    It 'デフォルトinvokerでOwner/Repository指定時に実行する' {
        $scriptPath = Join-Path $scriptRoot 'Setup-AzureResources.ps1'
        $global:DefaultOwner = 'nuitsjp'
        $global:DefaultRepository = 'swa-github-role-sync-ops'
        $defaultHostname = 'example.eastasia.azurestaticapps.net'
        $clientId = 'client-123'
        $principalId = 'principal-456'
        $tenantId = 'tenant-789'
        $subscriptionId = 'sub-000'
        $swaId = "/subscriptions/$subscriptionId/resourceGroups/rg-$($global:DefaultRepository)-prod/providers/Microsoft.Web/staticSites/stapp-$($global:DefaultRepository)-prod"

        $global:AzCalls = @()
        $global:GhCalls = @()

        function global:az {
            $global:AzCalls += ,$args
            switch -Wildcard ($args -join ' ') {
                'group exists*' { 'false' }
                '*staticwebapp show*defaultHostname*' { $defaultHostname }
                '*identity show*clientId*' { $clientId }
                '*identity show*principalId*' { $principalId }
                '*staticwebapp show* --query id *' { $swaId }
                '*account show*tenantId*' { $tenantId }
                '*account show* --query id *' { $subscriptionId }
                'role assignment create*' { }
            }
        }

        function global:gh {
            $global:GhCalls += ,$args
        }

        try {
            . $scriptPath

            Invoke-SetupAzureResources -Owner $global:DefaultOwner -Repository $global:DefaultRepository

            $global:AzCalls | ForEach-Object { $_ -join ' ' } | Should -Contain "group exists --name rg-$($global:DefaultRepository)-prod"
            $global:GhCalls | ForEach-Object { $_ -join ' ' } | Should -Contain "secret set AZURE_CLIENT_ID --body $clientId --repo $global:DefaultOwner/$global:DefaultRepository"
        }
        finally {
            Remove-Item Function:\az -ErrorAction SilentlyContinue
            Remove-Item Function:\gh -ErrorAction SilentlyContinue
            Remove-Variable -Name DefaultOwner -Scope Global -ErrorAction SilentlyContinue
            Remove-Variable -Name DefaultRepository -Scope Global -ErrorAction SilentlyContinue
        }
    }
}
