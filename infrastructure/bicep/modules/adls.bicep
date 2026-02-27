// =============================================================================
// ADLS Gen2: Storage Account, Containers, Private Endpoints, CMK, Diagnostics
// Deployed to: MVD-Core-rg
//
// Idempotency notes:
// - All resource names are deterministic (no random suffixes)
// - CMK uses a user-assigned managed identity to avoid chicken-and-egg
//   (system-assigned MI doesn't exist until the storage account is created,
//    but CMK config needs KV access at creation time)
//
// RBAC for ADF, Synapse, and Function App is handled by standalone
// rbac-assignment modules in main.bicep (avoids circular dependencies).
// =============================================================================

param location string
param storageAccountName string = 'mvdcoredatalake'
param keyVaultName string
param cmkKeyName string = 'adls-cmk'
param snetPrivateEndpointsId string
param logAnalyticsId string
param dnsZoneBlobId string
param dnsZoneDfsId string

// --- User-Assigned Managed Identity (for CMK access to Key Vault) -----------
// Created first so it can be granted KV access before the storage account
// tries to use the CMK key.

resource adlsIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${storageAccountName}'
  location: location
}

// Grant the identity access to the Key Vault encryption key
resource kvCryptoRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(adlsIdentity.id, keyVaultName, 'Key Vault Crypto Service Encryption User')
  scope: resourceGroup()
  properties: {
    principalId: adlsIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    // Key Vault Crypto Service Encryption User
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'e147488a-f6f5-4113-8e2d-b22465e65bf6')
  }
}

// --- Storage Account --------------------------------------------------------

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: { name: 'Standard_GRS' }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${adlsIdentity.id}': {}
    }
  }
  properties: {
    isHnsEnabled: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
    encryption: {
      identity: {
        userAssignedIdentity: adlsIdentity.id
      }
      services: {
        blob: { enabled: true, keyType: 'Account' }
        file: { enabled: true, keyType: 'Account' }
      }
      keySource: 'Microsoft.Keyvault'
      keyvaultproperties: {
        keyname: cmkKeyName
        keyvaulturi: 'https://${keyVaultName}${environment().suffixes.keyvaultDns}/'
      }
    }
  }
  dependsOn: [ kvCryptoRole ] // Identity must have KV access before storage account uses CMK
}

// --- Containers -------------------------------------------------------------

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 30
    }
  }
}

resource stagingContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'staging'
  properties: {
    publicAccess: 'None'
  }
}

resource goldContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'gold'
  properties: {
    publicAccess: 'None'
  }
}

resource synapseContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'synapse'
  properties: {
    publicAccess: 'None'
  }
}

// --- Lifecycle Management ---------------------------------------------------

resource lifecyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          name: 'cleanup-staging'
          enabled: true
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                delete: { daysAfterModificationGreaterThan: 30 }
              }
            }
            filters: {
              blobTypes: [ 'blockBlob' ]
              prefixMatch: [ 'staging/' ]
            }
          }
        }
      ]
    }
  }
}

// --- Private Endpoints ------------------------------------------------------

resource peDfs 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${storageAccountName}-dfs'
  location: location
  properties: {
    subnet: { id: snetPrivateEndpointsId }
    privateLinkServiceConnections: [
      {
        name: 'pec-${storageAccountName}-dfs'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [ 'dfs' ]
        }
      }
    ]
  }
}

resource peDfsDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: peDfs
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'dfs'
        properties: { privateDnsZoneId: dnsZoneDfsId }
      }
    ]
  }
}

resource peBlob 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${storageAccountName}-blob'
  location: location
  properties: {
    subnet: { id: snetPrivateEndpointsId }
    privateLinkServiceConnections: [
      {
        name: 'pec-${storageAccountName}-blob'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [ 'blob' ]
        }
      }
    ]
  }
}

resource peBlobDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: peBlob
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blob'
        properties: { privateDnsZoneId: dnsZoneBlobId }
      }
    ]
  }
}

// --- Diagnostic Settings ----------------------------------------------------

resource blobDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${storageAccountName}-blob'
  scope: blobService
  properties: {
    workspaceId: logAnalyticsId
    logs: [
      { categoryGroup: 'allLogs', enabled: true }
      { categoryGroup: 'audit', enabled: true }
    ]
    metrics: [
      { category: 'Transaction', enabled: true }
    ]
  }
}

// --- Advanced Threat Protection ---------------------------------------------

resource atp 'Microsoft.Security/advancedThreatProtectionSettings@2019-01-01' = {
  name: 'current'
  scope: storageAccount
  properties: {
    isEnabled: true
  }
}

// --- Outputs ----------------------------------------------------------------

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
