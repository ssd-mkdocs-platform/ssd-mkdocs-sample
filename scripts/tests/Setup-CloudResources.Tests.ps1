$ErrorActionPreference = 'Stop'

Describe 'Setup-CloudResources.ps1' {
    BeforeAll {
        $start = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).ProviderPath }
        $current = (Resolve-Path $start).ProviderPath

        while ($true) {
            $candidate = Join-Path -Path $current -ChildPath 'Setup-CloudResources.ps1'
            if (Test-Path $candidate) {
                $scriptPath = (Resolve-Path $candidate).ProviderPath
                break
            }

            $parent = Split-Path -Path $current -Parent
            if (-not $parent -or $parent -eq $current) {
                throw 'Setup-CloudResources.ps1 のパスを解決できません。'
            }
            $current = $parent
        }

        $scriptRoot = Split-Path -Path $scriptPath -Parent

        # ログ出力を抑制する
        Mock -CommandName Write-Host {}
    }

    It 'ドットソースしても外部CLIを呼び出さない' {
        $scriptPath = Join-Path $scriptRoot 'Setup-CloudResources.ps1'

        Mock -CommandName az { throw 'az should not be called when dot-sourced' }
        Mock -CommandName gh { throw 'gh should not be called when dot-sourced' }

        { . $scriptPath } | Should -Not -Throw
    }

    It '既存リソースグループがある場合はスキップして進む' {
        $scriptPath = Join-Path $scriptRoot 'Setup-CloudResources.ps1'
        $owner = 'nuitsjp'
        $repository = 'swa-github-role-sync-ops'

        $global:SetupAzCalls = @()
        $global:SetupGhCalls = @()
        $global:WriteHostMessages = @()

        Mock -CommandName Write-Host -MockWith {
            param($Object)
            $global:WriteHostMessages += $Object
        }

        $azInvoker = {
            $global:SetupAzCalls += ,$args
            switch -Wildcard ($args -join ' ') {
                'group exists*' { 'true' }
                '*staticwebapp show*defaultHostname*' { 'example.eastasia.azurestaticapps.net' }
                '*staticwebapp show* --query id *' { '/subscriptions/sub-000/resourceGroups/rg-swa-github-role-sync-ops-prod/providers/Microsoft.Web/staticSites/stapp-swa-github-role-sync-ops-prod' }
                '*identity show*clientId*' { 'client-123' }
                '*identity show*principalId*' { 'principal-456' }
                '*federated-credential show*' { }
                '*role assignment list*' { '[{"id":"dummy"}]' }
                '*staticwebapp secrets list*' { 'api-key-000' }
                '*account show*tenantId*' { 'tenant-789' }
                '*account show* --query id *' { 'sub-000' }
            }
        }

        $ghInvoker = {
            $global:SetupGhCalls += ,$args
            $cmd = $args -join ' '
            if ($cmd -like 'repo view*') {
                throw 'gh should not be called when Owner/Repository are provided'
            }
            if ($cmd -like 'repo edit*--enable-discussions*') {
                return $null
            }
            if ($cmd -like 'api graphql*discussionCategory*') {
                return '{"data":{"repository":{"discussionCategory":{"id":"DC_123"}}}}'
            }
            if ($cmd -like 'secret list*') {
                return '[{"name":"AZURE_CLIENT_ID"},{"name":"AZURE_TENANT_ID"},{"name":"AZURE_SUBSCRIPTION_ID"},{"name":"AZURE_STATIC_WEB_APPS_API_TOKEN"},{"name":"ROLE_SYNC_APP_ID"},{"name":"ROLE_SYNC_APP_PRIVATE_KEY"}]'
            }
        }

        & $scriptPath -Owner $owner -Repository $repository -AzInvoker $azInvoker -GhInvoker $ghInvoker

        $azCallLines = $global:SetupAzCalls | ForEach-Object { $_ -join ' ' }
        ($azCallLines | Where-Object { $_ -like 'group delete*' }).Count | Should -Be 0
        ($azCallLines | Where-Object { $_ -like 'group create*' }).Count | Should -Be 0
        ($azCallLines | Where-Object { $_ -like 'staticwebapp create*' }).Count | Should -Be 0
        ($azCallLines | Where-Object { $_ -like 'identity create*' }).Count | Should -Be 0
        ($azCallLines | Where-Object { $_ -like 'identity federated-credential create*' }).Count | Should -Be 0
        $ghCallLines = $global:SetupGhCalls | ForEach-Object { $_ -join ' ' }
        ($ghCallLines | Where-Object { $_ -like 'secret set*' }).Count | Should -Be 0
        $global:WriteHostMessages | Should -Contain 'SWA URL: https://example.eastasia.azurestaticapps.net'
    }

    It '既存リソースグループがある場合はForce指定で削除してから作成する' {
        $scriptPath = Join-Path $scriptRoot 'Setup-CloudResources.ps1'
        $owner = 'nuitsjp'
        $repository = 'swa-github-role-sync-ops'

        $global:SetupAzCalls = @()
        $global:SetupGhCalls = @()
        $global:RoleAssignmentAttempts = 0
        $global:GroupDeleteAttempts = 0
        $global:GroupWaitAttempts = 0
        $global:RgDeleted = $false

        $azInvoker = {
            $global:SetupAzCalls += ,$args
            $cmd = $args -join ' '

            switch -Wildcard ($cmd) {
                'group exists*' { 'true' }
                'group delete*' { $global:GroupDeleteAttempts++; $global:RgDeleted = $true }
                'group wait* --deleted*' { $global:GroupWaitAttempts++ }
                'group create*' { $global:RgDeleted = $false }
                # RG削除後は404を返す（リソースが存在しない）
                '*staticwebapp show*defaultHostname*' {
                    if ($global:RgDeleted) { throw 'Resource not found' }
                    'example.eastasia.azurestaticapps.net'
                }
                '*identity show*clientId*' {
                    if ($global:RgDeleted) { throw 'Resource not found' }
                    'client-123'
                }
                '*identity show*principalId*' { 'principal-456' }
                '*staticwebapp show* --query id *' { '/subscriptions/sub-000/resourceGroups/rg-swa-github-role-sync-ops-prod/providers/Microsoft.Web/staticSites/stapp-swa-github-role-sync-ops-prod' }
                '*staticwebapp secrets list*' { 'api-key-000' }
                '*account show*tenantId*' { 'tenant-789' }
                '*account show* --query id *' { 'sub-000' }
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
            $cmd = $args -join ' '
            if ($cmd -like 'repo view*') {
                throw 'gh repo view should not be called when Owner/Repository are provided'
            }
            if ($cmd -like 'repo edit*--enable-discussions*') {
                return $null
            }
            if ($cmd -like 'api graphql*discussionCategory*') {
                return '{"data":{"repository":{"discussionCategory":{"id":"DC_123"}}}}'
            }
            if ($cmd -like 'secret list*') {
                return '[]'
            }
        }

        $readHostInvoker = {
            param([string] $Prompt)
            switch -Wildcard ($Prompt) {
                '*App ID*' { 'dummy-app-id' }
                '*Private Key*' { 'TestDrive:\dummy.pem' }
            }
        }

        Mock -CommandName Start-Sleep -ParameterFilter { $Seconds -eq 15 }
        Mock -CommandName Get-Content -ParameterFilter { $Path -eq 'TestDrive:\dummy.pem' } -MockWith { 'dummy-private-key' }

        & $scriptPath -Owner $owner -Repository $repository -AzInvoker $azInvoker -GhInvoker $ghInvoker -ReadHostInvoker $readHostInvoker -Force

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
        $ghCallLines | Should -Contain 'secret set AZURE_CLIENT_ID --body client-123 --repo nuitsjp/swa-github-role-sync-ops'
        $azCallLines | Should -Contain "staticwebapp secrets list --name stapp-$repository-prod --resource-group rg-$repository-prod --query properties.apiKey -o tsv"
        $ghCallLines | Should -Contain 'secret set AZURE_STATIC_WEB_APPS_API_TOKEN --body api-key-000 --repo nuitsjp/swa-github-role-sync-ops'
    }

    It 'gh repo viewでOwner/Repositoryを解決する' {
        $scriptPath = Join-Path $scriptRoot 'Setup-CloudResources.ps1'
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
            $cmd = $args -join ' '
            if ($cmd -eq 'repo view --json owner,name') {
                return '{ "name": "spec-driven-docs-infra", "owner": { "login": "nuitsjp" } }'
            }
            if ($cmd -like 'repo edit*--enable-discussions*') {
                return $null
            }
            if ($cmd -like 'api graphql*discussionCategory*') {
                return '{"data":{"repository":{"discussionCategory":{"id":"DC_123"}}}}'
            }
            if ($cmd -like 'secret list*') {
                return '[]'
            }
        }

        $readHostInvoker = {
            param([string] $Prompt)
            switch -Wildcard ($Prompt) {
                '*App ID*' { 'dummy-app-id' }
                '*Private Key*' { 'TestDrive:\dummy.pem' }
            }
        }

        Mock -CommandName Start-Sleep -ParameterFilter { $Seconds -eq 15 }
        Mock -CommandName Get-Content -ParameterFilter { $Path -eq 'TestDrive:\dummy.pem' } -MockWith { 'dummy-private-key' }

        Invoke-SetupAzureResources -AzInvoker $azInvoker -GhInvoker $ghInvoker -ReadHostInvoker $readHostInvoker

        $global:SetupAzCalls | ForEach-Object { $_ -join ' ' } | Should -Contain 'group exists --name rg-spec-driven-docs-infra-prod'
        $global:SetupGhCalls | ForEach-Object { $_ -join ' ' } | Should -Contain 'repo view --json owner,name'
        Assert-MockCalled Start-Sleep -ParameterFilter { $Seconds -eq 15 } -Times 1
    }

    It 'ghが失敗したら例外を投げる' {
        $scriptPath = Join-Path $scriptRoot 'Setup-CloudResources.ps1'
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
        $scriptPath = Join-Path $scriptRoot 'Setup-CloudResources.ps1'
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
                '*staticwebapp show*defaultHostname*' { 'example.eastasia.azurestaticapps.net' }
                '*identity show*clientId*' { 'client-123' }
                '*identity show*principalId*' { 'principal-456' }
                '*staticwebapp show* --query id *' { '/subscriptions/sub-000/resourceGroups/rg-spec-driven-docs-infra-prod/providers/Microsoft.Web/staticSites/stapp-spec-driven-docs-infra-prod' }
                '*account show*tenantId*' { 'tenant-789' }
                '*account show* --query id *' { 'sub-000' }
                '*staticwebapp secrets list*' { 'api-key-000' }
                'role assignment create*' { }
            }
        }

        $ghInvoker = {
            $global:SetupGhCalls += ,$args
            $cmd = $args -join ' '
            if ($cmd -like 'repo edit*--enable-discussions*') {
                return $null
            }
            if ($cmd -like 'api graphql*discussionCategory*') {
                return '{"data":{"repository":{"discussionCategory":{"id":"DC_123"}}}}'
            }
            if ($cmd -like 'secret list*') {
                return '[]'
            }
        }

        $readHostInvoker = {
            param([string] $Prompt)
            switch -Wildcard ($Prompt) {
                '*App ID*' { 'dummy-app-id' }
                '*Private Key*' { 'TestDrive:\dummy.pem' }
            }
        }

        Mock -CommandName Get-Content -ParameterFilter { $Path -eq 'TestDrive:\dummy.pem' } -MockWith { 'dummy-private-key' }

        & $scriptPath -Owner $owner -Repository $repository -AzInvoker $azInvoker -GhInvoker $ghInvoker -ReadHostInvoker $readHostInvoker

        $global:WriteHostMessages | Should -Contain '  ✓ Set Actions secret AZURE_CLIENT_ID: client-123'
        $global:WriteHostMessages | Should -Contain '  ✓ Set Actions secret AZURE_TENANT_ID: tenant-789'
        $global:WriteHostMessages | Should -Contain '  ✓ Set Actions secret AZURE_SUBSCRIPTION_ID: sub-000'
        $global:WriteHostMessages | Should -Contain '  ✓ Set Actions secret AZURE_STATIC_WEB_APPS_API_TOKEN: (redacted)'
        # シークレット設定の出力行（✓を含む行）にリポジトリ名が含まれていないことを検証
        ($global:WriteHostMessages | Where-Object { $_ -like "*✓*$owner/$repository*" }).Count | Should -Be 0
    }

    It 'GitHub Apps対話入力でシークレットを設定する' {
        $scriptPath = Join-Path $scriptRoot 'Setup-CloudResources.ps1'
        $owner = 'nuitsjp'
        $repository = 'test-repo'
        $defaultHostname = 'example.eastasia.azurestaticapps.net'
        $clientId = 'client-123'
        $principalId = 'principal-456'
        $tenantId = 'tenant-789'
        $subscriptionId = 'sub-000'
        $apiKey = 'api-key-000'
        $swaId = "/subscriptions/$subscriptionId/resourceGroups/rg-$repository-prod/providers/Microsoft.Web/staticSites/stapp-$repository-prod"
        $appId = '12345678'
        $privateKey = '-----BEGIN RSA PRIVATE KEY-----\ntest\n-----END RSA PRIVATE KEY-----'

        $global:SetupAzCalls = @()
        $global:SetupGhCalls = @()
        $global:ReadHostCalls = @()

        $azInvoker = {
            $global:SetupAzCalls += ,$args
            switch -Wildcard ($args -join ' ') {
                'group exists*' { 'false' }
                '*staticwebapp show*defaultHostname*' { $defaultHostname }
                '*identity show*clientId*' { $clientId }
                '*identity show*principalId*' { $principalId }
                '*staticwebapp show* --query id *' { $swaId }
                '*staticwebapp secrets list*' { $apiKey }
                '*account show*tenantId*' { $tenantId }
                '*account show* --query id *' { $subscriptionId }
                'role assignment create*' { }
            }
        }

        $ghInvoker = {
            $global:SetupGhCalls += ,$args
            $cmd = $args -join ' '
            if ($cmd -like 'repo edit*--enable-discussions*') {
                return $null
            }
            if ($cmd -like 'api graphql*discussionCategory*') {
                return '{"data":{"repository":{"discussionCategory":{"id":"DC_123"}}}}'
            }
            if ($cmd -like 'secret list*') {
                return '[]'
            }
        }

        $readHostInvoker = {
            param([string] $Prompt)
            $global:ReadHostCalls += $Prompt
            switch -Wildcard ($Prompt) {
                '*App ID*' { $appId }
                '*Private Key*' { 'C:\temp\test.pem' }
            }
        }

        Mock -CommandName Get-Content -ParameterFilter { $Path -eq 'C:\temp\test.pem' } -MockWith { $privateKey }

        & $scriptPath -Owner $owner -Repository $repository -AzInvoker $azInvoker -GhInvoker $ghInvoker -ReadHostInvoker $readHostInvoker

        $ghCallLines = $global:SetupGhCalls | ForEach-Object { $_ -join ' ' }
        $ghCallLines | Should -Contain "secret set ROLE_SYNC_APP_ID --body $appId --repo $owner/$repository"
        $ghCallLines | Should -Contain "secret set ROLE_SYNC_APP_PRIVATE_KEY --body $privateKey --repo $owner/$repository"
        $global:ReadHostCalls.Count | Should -Be 2
    }

    It '既存シークレットがある場合はスキップして進む' {
        $scriptPath = Join-Path $scriptRoot 'Setup-CloudResources.ps1'
        $owner = 'nuitsjp'
        $repository = 'test-repo'

        $global:SetupAzCalls = @()
        $global:SetupGhCalls = @()
        $global:WriteHostMessages = @()

        Mock -CommandName Write-Host -MockWith {
            param($Object)
            $global:WriteHostMessages += $Object
        }

        $azInvoker = {
            $global:SetupAzCalls += ,$args
            switch -Wildcard ($args -join ' ') {
                'group exists*' { 'false' }
                '*staticwebapp show*defaultHostname*' { 'example.eastasia.azurestaticapps.net' }
                '*identity show*clientId*' { 'client-123' }
                '*identity show*principalId*' { 'principal-456' }
                '*staticwebapp show* --query id *' { '/subscriptions/sub-000/resourceGroups/rg-test-repo-prod/providers/Microsoft.Web/staticSites/stapp-test-repo-prod' }
                '*staticwebapp secrets list*' { 'api-key-000' }
                '*account show*tenantId*' { 'tenant-789' }
                '*account show* --query id *' { 'sub-000' }
                '*federated-credential show*' { }
                '*role assignment list*' { '[{"id":"dummy"}]' }
                'role assignment create*' { }
            }
        }

        $ghInvoker = {
            $global:SetupGhCalls += ,$args
            $cmd = $args -join ' '
            if ($cmd -like 'repo edit*--enable-discussions*') {
                return $null
            }
            if ($cmd -like 'api graphql*discussionCategory*') {
                return '{"data":{"repository":{"discussionCategory":{"id":"DC_123"}}}}'
            }
            if ($cmd -like 'secret list*') {
                return '[{"name":"AZURE_CLIENT_ID"},{"name":"AZURE_TENANT_ID"},{"name":"AZURE_SUBSCRIPTION_ID"},{"name":"AZURE_STATIC_WEB_APPS_API_TOKEN"},{"name":"ROLE_SYNC_APP_ID"},{"name":"ROLE_SYNC_APP_PRIVATE_KEY"}]'
            }
        }

        & $scriptPath -Owner $owner -Repository $repository -AzInvoker $azInvoker -GhInvoker $ghInvoker

        $ghCallLines = $global:SetupGhCalls | ForEach-Object { $_ -join ' ' }
        ($ghCallLines | Where-Object { $_ -like 'secret set*' }).Count | Should -Be 0
        $global:WriteHostMessages | Should -Contain 'SWA URL: https://example.eastasia.azurestaticapps.net'
    }

    It 'Discussionカテゴリーが既に存在する場合はスキップする' {
        $scriptPath = Join-Path $scriptRoot 'Setup-CloudResources.ps1'
        $owner = 'nuitsjp'
        $repository = 'test-repo'

        $global:SetupAzCalls = @()
        $global:SetupGhCalls = @()
        $global:WriteHostMessages = @()

        Mock -CommandName Write-Host -MockWith {
            param($Object)
            $global:WriteHostMessages += $Object
        }

        $azInvoker = {
            $global:SetupAzCalls += ,$args
            switch -Wildcard ($args -join ' ') {
                'group exists*' { 'false' }
                '*staticwebapp show*defaultHostname*' { 'example.eastasia.azurestaticapps.net' }
                '*identity show*clientId*' { 'client-123' }
                '*identity show*principalId*' { 'principal-456' }
                '*staticwebapp show* --query id *' { '/subscriptions/sub-000/resourceGroups/rg-test-repo-prod/providers/Microsoft.Web/staticSites/stapp-test-repo-prod' }
                '*staticwebapp secrets list*' { 'api-key-000' }
                '*account show*tenantId*' { 'tenant-789' }
                '*account show* --query id *' { 'sub-000' }
                '*federated-credential show*' { }
                '*role assignment list*' { '[{"id":"dummy"}]' }
                'role assignment create*' { }
            }
        }

        $ghInvoker = {
            $global:SetupGhCalls += ,$args
            $cmd = $args -join ' '
            if ($cmd -like 'repo edit*--enable-discussions*') {
                return $null
            }
            if ($cmd -like 'api graphql*discussionCategory*') {
                # カテゴリーが既に存在する
                return '{"data":{"repository":{"discussionCategory":{"id":"DC_123"}}}}'
            }
            if ($cmd -like 'secret list*') {
                return '[{"name":"AZURE_CLIENT_ID"},{"name":"AZURE_TENANT_ID"},{"name":"AZURE_SUBSCRIPTION_ID"},{"name":"AZURE_STATIC_WEB_APPS_API_TOKEN"},{"name":"ROLE_SYNC_APP_ID"},{"name":"ROLE_SYNC_APP_PRIVATE_KEY"}]'
            }
        }

        & $scriptPath -Owner $owner -Repository $repository -AzInvoker $azInvoker -GhInvoker $ghInvoker

        $ghCallLines = $global:SetupGhCalls | ForEach-Object { $_ -join ' ' }
        # Discussions有効化が呼ばれている
        ($ghCallLines | Where-Object { $_ -like 'repo edit*--enable-discussions*' }).Count | Should -Be 1
        # カテゴリー確認が呼ばれている
        ($ghCallLines | Where-Object { $_ -like 'api graphql*discussionCategory*' }).Count | Should -Be 1
        # スキップメッセージが表示されている
        $global:WriteHostMessages | Should -Contain '  Invitation category already exists (skipped)'
    }

    It 'Discussionカテゴリーが存在しない場合はループで案内する' {
        $scriptPath = Join-Path $scriptRoot 'Setup-CloudResources.ps1'
        $owner = 'nuitsjp'
        $repository = 'test-repo'

        $global:SetupAzCalls = @()
        $global:SetupGhCalls = @()
        $global:WriteHostMessages = @()
        $global:CategoryCheckCount = 0

        Mock -CommandName Write-Host -MockWith {
            param($Object)
            $global:WriteHostMessages += $Object
        }

        $azInvoker = {
            $global:SetupAzCalls += ,$args
            switch -Wildcard ($args -join ' ') {
                'group exists*' { 'false' }
                '*staticwebapp show*defaultHostname*' { 'example.eastasia.azurestaticapps.net' }
                '*identity show*clientId*' { 'client-123' }
                '*identity show*principalId*' { 'principal-456' }
                '*staticwebapp show* --query id *' { '/subscriptions/sub-000/resourceGroups/rg-test-repo-prod/providers/Microsoft.Web/staticSites/stapp-test-repo-prod' }
                '*staticwebapp secrets list*' { 'api-key-000' }
                '*account show*tenantId*' { 'tenant-789' }
                '*account show* --query id *' { 'sub-000' }
                '*federated-credential show*' { }
                '*role assignment list*' { '[{"id":"dummy"}]' }
                'role assignment create*' { }
            }
        }

        $ghInvoker = {
            $global:SetupGhCalls += ,$args
            $cmd = $args -join ' '
            if ($cmd -like 'repo edit*--enable-discussions*') {
                return $null
            }
            if ($cmd -like 'api graphql*discussionCategory*') {
                $global:CategoryCheckCount++
                if ($global:CategoryCheckCount -eq 1) {
                    # 1回目: 存在しない
                    return '{"data":{"repository":{"discussionCategory":null}}}'
                }
                # 2回目以降: 存在する
                return '{"data":{"repository":{"discussionCategory":{"id":"DC_123"}}}}'
            }
            if ($cmd -like 'secret list*') {
                return '[{"name":"AZURE_CLIENT_ID"},{"name":"AZURE_TENANT_ID"},{"name":"AZURE_SUBSCRIPTION_ID"},{"name":"AZURE_STATIC_WEB_APPS_API_TOKEN"},{"name":"ROLE_SYNC_APP_ID"},{"name":"ROLE_SYNC_APP_PRIVATE_KEY"}]'
            }
        }

        $readHostInvoker = {
            param([string] $Prompt)
            switch -Wildcard ($Prompt) {
                '*カテゴリー作成後*' { '' }
            }
        }

        & $scriptPath -Owner $owner -Repository $repository -AzInvoker $azInvoker -GhInvoker $ghInvoker -ReadHostInvoker $readHostInvoker

        $ghCallLines = $global:SetupGhCalls | ForEach-Object { $_ -join ' ' }
        # Discussions有効化が呼ばれている
        ($ghCallLines | Where-Object { $_ -like 'repo edit*--enable-discussions*' }).Count | Should -Be 1
        # カテゴリー確認が2回呼ばれている（1回目:存在しない、2回目:存在する）
        $global:CategoryCheckCount | Should -Be 2
        # 案内メッセージが表示されている
        $global:WriteHostMessages | Should -Contain '=== GitHub Discussions Setup ==='
        # 確認完了メッセージが表示されている
        $global:WriteHostMessages | Should -Contain '  ✓ Invitation category verified'
    }

    It 'デフォルトinvokerでOwner/Repository指定時に実行する' {
        $scriptPath = Join-Path $scriptRoot 'Setup-CloudResources.ps1'
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
                '*staticwebapp show*defaultHostname*' { 'example.eastasia.azurestaticapps.net' }
                '*identity show*clientId*' { 'client-123' }
                '*identity show*principalId*' { 'principal-456' }
                '*staticwebapp show* --query id *' { "/subscriptions/sub-000/resourceGroups/rg-$($global:DefaultRepository)-prod/providers/Microsoft.Web/staticSites/stapp-$($global:DefaultRepository)-prod" }
                '*account show*tenantId*' { 'tenant-789' }
                '*account show* --query id *' { 'sub-000' }
                'role assignment create*' { }
            }
        }

        function global:gh {
            $global:GhCalls += ,$args
            $cmd = $args -join ' '
            if ($cmd -like 'repo edit*--enable-discussions*') {
                return $null
            }
            if ($cmd -like 'api graphql*discussionCategory*') {
                return '{"data":{"repository":{"discussionCategory":{"id":"DC_123"}}}}'
            }
            if ($cmd -like 'secret list*') {
                return '[]'
            }
        }

        $global:ReadHostCallCount = 0
        Mock -CommandName Read-Host -MockWith {
            $global:ReadHostCallCount++
            if ($global:ReadHostCallCount -eq 1) {
                return 'dummy-app-id'
            } else {
                return 'TestDrive:\dummy.pem'
            }
        }
        Mock -CommandName Get-Content -ParameterFilter { $Path -eq 'TestDrive:\dummy.pem' } -MockWith { 'dummy-private-key' }

        try {
            . $scriptPath

            Invoke-SetupAzureResources -Owner $global:DefaultOwner -Repository $global:DefaultRepository

            $global:AzCalls | ForEach-Object { $_ -join ' ' } | Should -Contain "group exists --name rg-$($global:DefaultRepository)-prod"
            $global:GhCalls | ForEach-Object { $_ -join ' ' } | Should -Contain "secret set AZURE_CLIENT_ID --body client-123 --repo $($global:DefaultOwner)/$($global:DefaultRepository)"
        }
        finally {
            Remove-Item Function:\az -ErrorAction SilentlyContinue
            Remove-Item Function:\gh -ErrorAction SilentlyContinue
            Remove-Variable -Name DefaultOwner -Scope Global -ErrorAction SilentlyContinue
            Remove-Variable -Name DefaultRepository -Scope Global -ErrorAction SilentlyContinue
        }
    }
}
