// =============================================================================
// Core Security: Reference existing Key Vault + Log Analytics, add CMK key
// Deployed to: MVD-Core-rg
//
// References existing:
//   - Key Vault: kv-miravista-core (updates to enable purge protection for CMK)
//   - Log Analytics: log-miravista-core
//
// Creates new:
//   - CMK encryption key (adls-cmk) in existing Key Vault
//   - Key Vault private endpoint
// =============================================================================

param location string
param keyVaultName string = 'kv-miravista-core'
param logAnalyticsName string = 'log-miravista-core'
param snetPrivateEndpointsId string
param dnsZoneVaultId string

// --- Reference Existing Log Analytics ----------------------------------------

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsName
}

// --- Update Existing Key Vault (enable purge protection for CMK) -------------
// This is an upsert -- preserves existing config, enables purge protection.
// Purge protection is REQUIRED for CMK encryption on ADLS.

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
    publicNetworkAccess: 'Enabled' // Matches current state -- tighten later if needed
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
