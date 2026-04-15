// 参加者ごとの Container App
// Deploy-HandsonEnv.ps1 から参加者数分デプロイされる

@description('デプロイ先リージョン')
param location string = resourceGroup().location

@description('Container Apps Environment のリソースID')
param environmentId string

@description('ACR のログインサーバー (例: xxx.azurecr.io)')
param acrLoginServer string

@description('User Assigned Managed Identity のリソースID')
param identityId string

@description('コンテナイメージ名')
param imageName string = 'handson-env'

@description('コンテナイメージタグ')
param imageTag string

@description('参加者識別名 (例: user-01)')
param userName string

@secure()
@description('code-server のパスワード')
param password string

var appName = 'handson-${userName}'

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8080
        transport: 'auto'
        allowInsecure: false
      }
      registries: [
        {
          server: acrLoginServer
          identity: identityId
        }
      ]
      secrets: [
        {
          name: 'code-server-password'
          value: password
        }
      ]
    }
    template: {
      containers: [
        {
          name: appName
          image: '${acrLoginServer}/${imageName}:${imageTag}'
          resources: {
            cpu: json('1.0')
            memory: '2Gi'
          }
          env: [
            {
              name: 'PASSWORD'
              secretRef: 'code-server-password'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

output fqdn string = app.properties.configuration.ingress.fqdn
output appName string = app.name
