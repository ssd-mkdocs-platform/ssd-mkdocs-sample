$ErrorActionPreference = 'Stop'

Describe 'setup-azure-resources.ps1' {
    It '指定したownerとrepositoryでAzureとGitHubの設定を呼び出す' {
        $scriptPath = Join-Path $PSScriptRoot 'setup-azure-resources.ps1'
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

        $azInvoker = {
            $global:SetupAzCalls += ,$args

            switch -Wildcard ($args -join ' ') {
                '*staticwebapp show*defaultHostname*' { $defaultHostname }
                '*identity show*clientId*' { $clientId }
                '*identity show*principalId*' { $principalId }
                '*staticwebapp show* --query id *' { $swaId }
                '*account show*tenantId*' { $tenantId }
                '*account show* --query id *' { $subscriptionId }
            }
        }

        $ghInvoker = {
            $global:SetupGhCalls += ,$args
        }

        Mock -CommandName Start-Sleep -ParameterFilter { $Seconds -eq 15 }

        & $scriptPath -Owner $owner -Repository $repository -AzInvoker $azInvoker -GhInvoker $ghInvoker

        Assert-MockCalled Start-Sleep -ParameterFilter { $Seconds -eq 15 } -Times 1

        $azCallLines = $global:SetupAzCalls | ForEach-Object { $_ -join ' ' }
        $ghCallLines = $global:SetupGhCalls | ForEach-Object { $_ -join ' ' }

        $azCallLines | Should -Contain "group create --name rg-$repository-prod --location japaneast -o none"
        $azCallLines | Should -Contain "staticwebapp create --name stapp-$repository-prod --resource-group rg-$repository-prod --location eastasia --sku Standard -o none"
        $azCallLines | Should -Contain "staticwebapp show --name stapp-$repository-prod --resource-group rg-$repository-prod --query defaultHostname -o tsv"
        $azCallLines | Should -Contain "identity create --name id-$repository-prod --resource-group rg-$repository-prod --location japaneast -o none"
        $azCallLines | Should -Contain "identity show --name id-$repository-prod --resource-group rg-$repository-prod --query clientId -o tsv"
        $azCallLines | Should -Contain "identity show --name id-$repository-prod --resource-group rg-$repository-prod --query principalId -o tsv"
        $azCallLines | Should -Contain "identity federated-credential create --name fc-github-actions-main --identity-name id-$repository-prod --resource-group rg-$repository-prod --issuer https://token.actions.githubusercontent.com --subject repo:${owner}/${repository}:ref:refs/heads/main --audiences api://AzureADTokenExchange -o none"
        $azCallLines | Should -Contain "staticwebapp show --name stapp-$repository-prod --resource-group rg-$repository-prod --query id -o tsv"
        $azCallLines | Should -Contain "role assignment create --assignee-object-id $principalId --assignee-principal-type ServicePrincipal --role Contributor --scope $swaId -o none"
        $azCallLines | Should -Contain 'account show --query tenantId -o tsv'
        $azCallLines | Should -Contain 'account show --query id -o tsv'
        $ghCallLines | Should -Contain "secret set AZURE_CLIENT_ID --body $clientId --repo $owner/$repository"
        $ghCallLines | Should -Contain "secret set AZURE_TENANT_ID --body $tenantId --repo $owner/$repository"
        $ghCallLines | Should -Contain "secret set AZURE_SUBSCRIPTION_ID --body $subscriptionId --repo $owner/$repository"
    }
}
