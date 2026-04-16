# クラウド環境構築手順

## 前提条件

- Azure サブスクリプションに対するリソース作成権限があること
- GitHub リポジトリの管理者権限があること
- `az` CLI と `gh` CLI がインストール済みであること
- `az login` と `gh auth login` が完了していること

## 手順

### 1. 命名規則とパラメーターを設定する

GitHubのOwnerとRepository名を設定する。

=== "PowerShell"

    ```powershell
    $Owner = "<org-or-user>"
    $Repository = "<repo>"
    $githubRepo = "$Owner/$Repository"

    $location = "japaneast"
    $swaLocation = "eastasia"

    $resourceGroupName = "rg-$Repository-prod"
    $swaName = "stapp-$Repository-prod"
    $identityName = "id-$Repository-prod"
    $federatedCredentialName = "fc-github-actions-main"
    ```

=== "Bash"

    ```bash
    Owner="<org-or-user>"
    Repository="<repo>"
    githubRepo="${Owner}/${Repository}"

    location="japaneast"
    swaLocation="eastasia"

    resourceGroupName="rg-${Repository}-prod"
    swaName="stapp-${Repository}-prod"
    identityName="id-${Repository}-prod"
    federatedCredentialName="fc-github-actions-main"
    ```

### 2. リソースグループと Static Web App の作成

=== "PowerShell"

    ```powershell
    az group create --name $resourceGroupName --location $location

    az staticwebapp create `
      --name $swaName `
      --resource-group $resourceGroupName `
      --location $swaLocation `
      --sku Standard

    $defaultHostname = az staticwebapp show `
      --name $swaName `
      --resource-group $resourceGroupName `
      --query defaultHostname `
      -o tsv
    ```

=== "Bash"

    ```bash
    az group create --name $resourceGroupName --location $location

    az staticwebapp create \
      --name $swaName \
      --resource-group $resourceGroupName \
      --location $swaLocation \
      --sku Standard

    defaultHostname=$(az staticwebapp show \
      --name $swaName \
      --resource-group $resourceGroupName \
      --query defaultHostname \
      -o tsv)
    ```

### 3. マネージド ID と OIDC フェデレーション資格情報の作成

既定ブランチが `main` 以外の場合は `--subject` の `refs/heads/main` を置き換える。

=== "PowerShell"

    ```powershell
    az identity create --name $identityName --resource-group $resourceGroupName --location $location

    $identity = az identity show `
      --name $identityName `
      --resource-group $resourceGroupName `
      --query "{clientId:clientId, principalId:principalId}" `
      -o json | ConvertFrom-Json
    $clientId = $identity.clientId
    $principalId = $identity.principalId

    az identity federated-credential create `
      --name $federatedCredentialName `
      --identity-name $identityName `
      --resource-group $resourceGroupName `
      --issuer "https://token.actions.githubusercontent.com" `
      --subject "repo:$githubRepo:ref:refs/heads/main" `
      --audiences "api://AzureADTokenExchange"
    ```

=== "Bash"

    ```bash
    az identity create --name $identityName --resource-group $resourceGroupName --location $location

    clientId=$(az identity show \
      --name $identityName \
      --resource-group $resourceGroupName \
      --query clientId \
      -o tsv)
    principalId=$(az identity show \
      --name $identityName \
      --resource-group $resourceGroupName \
      --query principalId \
      -o tsv)

    az identity federated-credential create \
      --name $federatedCredentialName \
      --identity-name $identityName \
      --resource-group $resourceGroupName \
      --issuer "https://token.actions.githubusercontent.com" \
      --subject "repo:$githubRepo:ref:refs/heads/main" \
      --audiences "api://AzureADTokenExchange"
    ```

### 4. Static Web App への RBAC 付与

伝播待ちで失敗する場合は数十秒待って再実行する。

=== "PowerShell"

    ```powershell
    $swaId = az staticwebapp show `
      --name $swaName `
      --resource-group $resourceGroupName `
      --query id `
      -o tsv
    az role assignment create `
      --assignee-object-id $principalId `
      --assignee-principal-type ServicePrincipal `
      --role Contributor `
      --scope $swaId
    ```

=== "Bash"

    ```bash
    swaId=$(az staticwebapp show \
      --name $swaName \
      --resource-group $resourceGroupName \
      --query id \
      -o tsv)
    az role assignment create \
      --assignee-object-id $principalId \
      --assignee-principal-type ServicePrincipal \
      --role Contributor \
      --scope $swaId
    ```

### 5. GitHub Pages の有効化

GitHub Pagesにデプロイするため、リポジトリ設定で有効化する必要がある。

1. GitHub リポジトリの `Settings -> Pages` に移動する。
2. `Build and deployment` の `Source` で `GitHub Actions` を選択する。

!!! note "Environment の自動作成"
    GitHub Actions をソースに設定すると、`github-pages` という名前の environment が自動的に作成される。ワークフローはこの environment を使用してデプロイを行う。

### 6. GitHub Discussions の有効化とカテゴリ作成

```shell
gh repo edit $githubRepo --enable-discussions
```

1. GitHub の `Settings -> Discussions` に移動する。
2. `Set up discussions` をクリックする（初回のみ）。
3. `Categories -> New category` をクリックする。
4. `Name: Invitation`, `Description: SWA role sync invitations`, `Format: Announcement` を設定して作成する。

### 7. GitHub Actions の Variables と Secrets の登録

=== "PowerShell"

    ```powershell
    $tenantId = az account show --query tenantId -o tsv
    $subscriptionId = az account show --query id -o tsv
    $swaApiToken = az staticwebapp secrets list `
      --name $swaName `
      --resource-group $resourceGroupName `
      --query properties.apiKey `
      -o tsv

    gh variable set AZURE_CLIENT_ID --body $clientId --repo $githubRepo
    gh variable set AZURE_TENANT_ID --body $tenantId --repo $githubRepo
    gh variable set AZURE_SUBSCRIPTION_ID --body $subscriptionId --repo $githubRepo
    gh variable set AZURE_SWA_NAME --body $swaName --repo $githubRepo
    gh variable set AZURE_SWA_RESOURCE_GROUP --body $resourceGroupName --repo $githubRepo

    gh secret set AZURE_SWA_API_TOKEN --body $swaApiToken --repo $githubRepo
    ```

=== "Bash"

    ```bash
    tenantId=$(az account show --query tenantId -o tsv)
    subscriptionId=$(az account show --query id -o tsv)
    swaApiToken=$(az staticwebapp secrets list \
      --name $swaName \
      --resource-group $resourceGroupName \
      --query properties.apiKey \
      -o tsv)

    gh variable set AZURE_CLIENT_ID --body "${clientId}" --repo $githubRepo
    gh variable set AZURE_TENANT_ID --body "${tenantId}" --repo $githubRepo
    gh variable set AZURE_SUBSCRIPTION_ID --body "${subscriptionId}" --repo $githubRepo
    gh variable set AZURE_SWA_NAME --body "${swaName}" --repo $githubRepo
    gh variable set AZURE_SWA_RESOURCE_GROUP --body "${resourceGroupName}" --repo $githubRepo

    gh secret set AZURE_SWA_API_TOKEN --body "${swaApiToken}" --repo $githubRepo
    ```

### 8. GitHub App の作成と連携情報の登録

1. `GitHub -> Settings -> Developer settings -> GitHub Apps -> New GitHub App` を開く。
2. `App name` は任意、`Homepage URL` はリポジトリ URL を入力する。
3. `Webhook` の `Active` をオフにする。
4. `Permissions -> Repository -> Discussions: Read and write` を設定する。
5. `Create GitHub App` をクリックする。
6. `App ID` を控える。
7. `Private keys -> Generate a private key` で PEM をダウンロードする。
8. 連携情報を登録する：

=== "PowerShell"

    ```powershell
    gh variable set ROLE_SYNC_APP_ID --body "<appId>" --repo $githubRepo
    gh secret set ROLE_SYNC_APP_PRIVATE_KEY --body (Get-Content -Raw -Path "<pemPath>") --repo $githubRepo
    ```

=== "Bash"

    ```bash
    gh variable set ROLE_SYNC_APP_ID --body "<appId>" --repo $githubRepo
    gh secret set ROLE_SYNC_APP_PRIVATE_KEY --body "$(cat '<pemPath>')" --repo $githubRepo
    ```

## 完了確認

- `https://$defaultHostname` にアクセスできることを確認する。
