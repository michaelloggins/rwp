// =============================================================================
// Core Security: Key Vault, Log Analytics Workspace
// Deployed to: MVD-Core-rg
// =============================================================================

param location string
param keyVaultName string = 'mvd-core-kv'
param logAnalyticsName string = 'mvd-core-logs'
param snetPrivateEndpointsId string
param dnsZoneVaultId string

// --- Log Analytics Workspace ------------------------------------------------

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 90
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// --- Key Vault --------------------------------------------------------------

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enablePurgeProtection: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

// CMK encryption key for ADLS
resource adlsCmk 'Microsoft.KeyVault/vaults/keys@2023-07-01' = {
  parent: keyVault
  name: 'adls-cmk'
  properties: {
    kty: 'RSA'
    keySize: 2048
    keyOps: [ 'wrapKey', 'unwrapKey' ]
  }
}

// --- Key Vault Private Endpoint ---------------------------------------------

resource kvPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${keyVaultName}-vault'
  location: location
  properties: {
    subnet: { id: snetPrivateEndpointsId }
    privateLinkServiceConnections: [
      {
        name: 'pec-${keyVaultName}-vault'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [ 'vault' ]
        }
      }
    ]
  }
}

resource kvDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: kvPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'keyvault'
        properties: {
          privateDnsZoneId: dnsZoneVaultId
        }
      }
    ]
  }
}

// --- Key Vault Diagnostics --------------------------------------------------

resource kvDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${keyVaultName}'
  scope: keyVault
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      { categoryGroup: 'allLogs', enabled: true }
      { categoryGroup: 'audit', enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}

// --- Outputs ----------------------------------------------------------------

output logAnalyticsId string = logAnalytics.id
output logAnalyticsName string = logAnalytics.name
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output adlsCmkName string = adlsCmk.name
output adlsCmkUri string = adlsCmk.properties.keyUriWithVersion
