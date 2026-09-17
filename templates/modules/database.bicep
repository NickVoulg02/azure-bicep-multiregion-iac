param location string
param sqlServerName string
param sqlDatabaseName string

@secure()
param sqlServerAdministratorLogin string

@secure()
param sqlServerAdministratorPassword string

param sqlDatabaseSku object
param auditingEnabled bool

var auditingStorageAccountName = 'toyaudit${uniqueString(resourceGroup().id, location)}'
var auditingStorageAccountSkuName = 'Standard_LRS'

resource sqlServer 'Microsoft.Sql/servers@2024-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlServerAdministratorLogin
    administratorLoginPassword: sqlServerAdministratorPassword
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2024-05-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  sku: {
    name: sqlDatabaseSku.name
    tier: sqlDatabaseSku.tier
  }
}

resource auditingStorageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = if (auditingEnabled) {
  name: auditingStorageAccountName
  location: location
  sku: {
    name: auditingStorageAccountSkuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

resource sqlServerAudit 'Microsoft.Sql/servers/auditingSettings@2024-05-01-preview' = if (auditingEnabled) {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    storageEndpoint: auditingEnabled ? auditingStorageAccount.properties.primaryEndpoints.blob : ''
    storageAccountAccessKey: auditingEnabled ? auditingStorageAccount.listKeys().keys[0].value : ''
  }
}

output serverName string = sqlServer.name
output location string = location
output serverFullyQualifiedDomainName string = sqlServer.properties.fullyQualifiedDomainName
