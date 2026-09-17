@description('The name of the environment. This must be dev, test, or prod.')
@allowed([
  'dev'
  'test'
  'prod'
])
param environmentName string = 'dev'

@description('Indicates whether auditing is enabled on the SQL server. Defaults to true for prod.')
param auditingEnabled bool = (environmentName == 'prod')

@description('The unique name of the solution. This is used to ensure that resource names are unique.')
@minLength(5)
@maxLength(30)
param solutionName string = 'toyhr${uniqueString(resourceGroup().id)}'

@description('The number of App Service plan instances.')
@minValue(1)
@maxValue(10)
param appServicePlanInstanceCount int = 1

@description('The name and tier of the App Service plan SKU.')
param appServicePlanSku object

@description('The Azure regions into which the databases should be deployed.')
param locations array = [
  'westus3'
  'centralus'
]

param storageAccountName string = 'toylaunch${uniqueString(resourceGroup().id)}'

@secure()
@description('The administrator login username for the SQL server.')
param sqlServerAdministratorLogin string

@secure()
@description('The administrator login password for the SQL server.')
param sqlServerAdministratorPassword string

@description('The name and tier of the SQL database SKU.')
param sqlDatabaseSku object

var appServicePlanName = '${environmentName}-${solutionName}-plan'
var appServiceAppName = '${environmentName}-${solutionName}-app'
var sqlDatabaseName = 'Employees'

var storageAccountSkuName = (environmentName == 'prod') ? 'Standard_GRS' : 'Standard_LRS'

var subnets = [
  {
    name: 'frontend'
    ipAddressRange: '10.0.0.0/24'
  }
  {
    name: 'backend'
    ipAddressRange: '10.0.1.0/24'
  }
]

// The main storage account stays in the Resource Group's primary location
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: resourceGroup().location
  sku: {
    name: storageAccountSkuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

resource virtualNetworks 'Microsoft.Network/virtualNetworks@2023-11-01' = [for location in locations: {
  name: '${environmentName}-${solutionName}-${location}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.ipAddressRange
      }
    }]
  }
}]

module database 'modules/database.bicep' = [for location in locations: {
  name: 'database-${location}'
  params: {
    location: location
    sqlServerName: '${environmentName}-${solutionName}-${location}-sql'
    sqlDatabaseName: sqlDatabaseName
    sqlServerAdministratorLogin: sqlServerAdministratorLogin
    sqlServerAdministratorPassword: sqlServerAdministratorPassword
    sqlDatabaseSku: sqlDatabaseSku
    auditingEnabled: auditingEnabled
  }
}]

module appService 'modules/appService.bicep' = {
  name: 'appService'
  params: {
    location: resourceGroup().location
    appServiceAppName: appServiceAppName
    appServicePlanName: appServicePlanName
    appServicePlanInstanceCount: appServicePlanInstanceCount
    appServicePlanSku: appServicePlanSku
  }
}

output databaseServerInfo array = [for i in range(0, length(locations)): {
  name: database[i].outputs.serverName
  location: database[i].outputs.location
  fqdn: database[i].outputs.serverFullyQualifiedDomainName
}]
