// ハンズオン共有インフラストラクチャ
// - Azure Container Registry
// - User Assigned Managed Identity + AcrPull ロール割り当て
// - Log Analytics Workspace
// - Container Apps Environment

@description('デプロイ先リージョン')
param location string = resourceGroup().location

// リソースグループ名からベース名を導出（rg- プレフィックスを除去）
var baseName = startsWith(resourceGroup().name, 'rg-')
  ? substring(resourceGroup().name, 3)
  : resourceGroup().name
var suffix = uniqueString(resourceGroup().id)

// ACR名はグローバル一意が必要なため suffix を使用
var acrName = 'acr${suffix}'
var identityName = 'id-${baseName}'
var workspaceName = 'log-${suffix}'
var envName = 'cae-${baseName}'

// AcrPull ロールの定義ID
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

// ---------- Container Registry ----------
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: { name: 'Basic' }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

// ---------- Managed Identity ----------
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

// ---------- AcrPull ロール割り当て ----------
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, identity.id, acrPullRoleId)
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// ---------- Log Analytics Workspace ----------
resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

// ---------- Container Apps Environment ----------
resource env 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: envName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: workspace.properties.customerId
        sharedKey: workspace.listKeys().primarySharedKey
      }
    }
  }
}

// ---------- Outputs ----------
output acrName string = acr.name
output acrLoginServer string = acr.properties.loginServer
output environmentId string = env.id
output identityId string = identity.id
