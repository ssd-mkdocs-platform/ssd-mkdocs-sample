// ハンズオン共有インフラストラクチャ
// - Log Analytics Workspace
// - Container Apps Environment

@description('デプロイ先リージョン')
param location string = resourceGroup().location

// リソースグループ名からベース名を導出（rg- プレフィックスを除去）
var baseName = startsWith(resourceGroup().name, 'rg-')
  ? substring(resourceGroup().name, 3)
  : resourceGroup().name
var suffix = uniqueString(resourceGroup().id)

var workspaceName = 'log-${suffix}'
var envName = 'cae-${baseName}'

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
output environmentId string = env.id
