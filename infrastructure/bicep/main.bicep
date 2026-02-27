// =============================================================================
// RWP Infrastructure - Main Orchestrator
// Scope: Subscription (creates resource groups, then deploys modules into them)
//
// Usage:
//   az deployment sub create \
//     --location centralus \
//     --template-file main.bicep \
//     --parameters main.bicepparam \
//     --parameters sqlAdministratorLoginPassword='<secure-password>'
// =============================================================================

targetScope = 'subscription'

// --- Parameters -------------------------------------------------------------

@description('Region for all resources')
param location string = 'centralus'

@description('Shared platform resource group')
param coreResourceGroup string = 'MVD-Core-rg'

@description('RWP project resource group')
param rwpResourceGroup string = 'rg-rwp-cus-001'

@description('SQL administrator password for Synapse Serverless')
@secure()
param sqlAdministratorLoginPassword string

// --- Resource Groups --------------------------------------------------------

resource rgCore 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: coreResourceGroup
}

resource rgRwp 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rwpResourceGroup
  location: location
}

// =============================================================================
// CORE RESOURCE GROUP DEPLOYMENTS
// =============================================================================

// --- 1. Networking (existing VNet + new subnets + DNS zones) -----------------

module networking 'modules/core-networking.bicep' = {
  name: 'deploy-core-networking'
  scope: rgCore
  params: {
    location: location
  }
}

// --- 2. Security (existing KV + Log Analytics, add CMK key) -----------------

module security 'modules/core-security.bicep' = {
  name: 'deploy-core-security'
  scope: rgCore
  params: {
    location: location
    snetPrivateEndpointsId: networking.outputs.snetPrivateEndpointsId
    dnsZoneVaultId: networking.outputs.dnsZoneIds.vault
  }
}

// --- 3. ADLS Gen2 -----------------------------------------------------------

module adls 'modules/adls.bicep' = {
  name: 'deploy-adls'
  scope: rgCore
  params: {
    location: location
    keyVaultName: security.outputs.keyVaultName
    snetPrivateEndpointsId: networking.outputs.snetPrivateEndpointsId
    logAnalyticsId: security.outputs.logAnalyticsId
    dnsZoneBlobId: networking.outputs.dnsZoneIds.blob
    dnsZoneDfsId: networking.outputs.dnsZoneIds.dfs
  }
}

// --- 4. Synapse Serverless Workspace ----------------------------------------

module synapse 'modules/synapse.bicep' = {
  name: 'deploy-synapse'
  scope: rgCore
  params: {
    location: location
    defaultDataLakeAccountName: adls.outputs.storageAccountName
    sqlAdministratorLoginPassword: sqlAdministratorLoginPassword
    logAnalyticsId: security.outputs.logAnalyticsId
  }
}

// --- 5. Azure Data Factory --------------------------------------------------

module adf 'modules/adf.bicep' = {
  name: 'deploy-adf'
  scope: rgCore
  params: {
    location: location
    logAnalyticsId: security.outputs.logAnalyticsId
  }
}

// --- 6. Security Hardening (private endpoints + alerts for Synapse & ADF) ---

module hardening 'modules/security-hardening.bicep' = {
  name: 'deploy-security-hardening'
  scope: rgCore
  params: {
    location: location
    snetPrivateEndpointsId: networking.outputs.snetPrivateEndpointsId
    dnsZoneSqlId: networking.outputs.dnsZoneIds.sql
    dnsZoneAdfId: networking.outputs.dnsZoneIds.adf
    synapseWorkspaceId: synapse.outputs.synapseWorkspaceId
    synapseWorkspaceName: synapse.outputs.synapseWorkspaceName
    adfId: adf.outputs.adfId
    adfName: adf.outputs.adfName
  }
}

// =============================================================================
// RWP RESOURCE GROUP DEPLOYMENT
// =============================================================================

// --- 7. Function App --------------------------------------------------------

module rwpApp 'modules/rwp-function-app.bicep' = {
  name: 'deploy-rwp-function-app'
  scope: rgRwp
  params: {
    location: location
    logAnalyticsId: security.outputs.logAnalyticsId
    snetFunctionsId: networking.outputs.snetFunctionsId
    synapseEndpoint: synapse.outputs.synapseEndpoint
  }
}

// =============================================================================
// POST-DEPLOYMENT: RBAC Assignments on ADLS
// =============================================================================
// Standalone modules -- each only creates a single role assignment.
// Safe to run repeatedly (idempotent via deterministic guid()).

var storageBlobDataContributor = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var storageBlobDataReader = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'

// Synapse needs Contributor to write to its default filesystem
module synapseAdlsRbac 'modules/rbac-assignment.bicep' = {
  name: 'deploy-synapse-adls-rbac'
  scope: rgCore
  params: {
    storageAccountName: adls.outputs.storageAccountName
    principalId: synapse.outputs.synapsePrincipalId
    roleDefinitionId: storageBlobDataContributor
  }
}

// ADF needs Contributor to read/write staging and gold zones
module adfAdlsRbac 'modules/rbac-assignment.bicep' = {
  name: 'deploy-adf-adls-rbac'
  scope: rgCore
  params: {
    storageAccountName: adls.outputs.storageAccountName
    principalId: adf.outputs.adfPrincipalId
    roleDefinitionId: storageBlobDataContributor
  }
}

// Function App needs Reader to query via Synapse external tables
module funcAdlsRbac 'modules/rbac-assignment.bicep' = {
  name: 'deploy-func-adls-rbac'
  scope: rgCore
  params: {
    storageAccountName: adls.outputs.storageAccountName
    principalId: rwpApp.outputs.functionAppPrincipalId
    roleDefinitionId: storageBlobDataReader
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

output functionAppHostName string = rwpApp.outputs.functionAppDefaultHostName
output functionAppName string = rwpApp.outputs.functionAppName
output functionAppPrincipalId string = rwpApp.outputs.functionAppPrincipalId
output adlsStorageAccountName string = adls.outputs.storageAccountName
output synapseWorkspaceName string = synapse.outputs.synapseWorkspaceName
output synapseEndpoint string = synapse.outputs.synapseEndpoint
output adfName string = adf.outputs.adfName
output logAnalyticsName string = security.outputs.logAnalyticsName
output keyVaultName string = security.outputs.keyVaultName
output vnetName string = networking.outputs.vnetName
