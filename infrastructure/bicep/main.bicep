// =============================================================================
// RWP Infrastructure - Main Orchestrator
// Scope: Subscription (creates resource groups, then deploys modules into them)
//
// Usage:
//   az deployment sub create \
//     --location centralus \
//     --template-file main.bicep \
//     --parameters main.bicepparam
// =============================================================================

targetScope = 'subscription'

// --- Parameters -------------------------------------------------------------

@description('Region for all resources')
param location string = 'centralus'

@description('Shared platform resource group')
param coreResourceGroup string = 'MVD-Core-rg'

@description('RWP project resource group')
param rwpResourceGroup string = 'rg-rwp-cus-001'

@description('Name of existing Synapse workspace in MVD-Core-rg')
param synapseWorkspaceName string

@description('Name of existing ADF in MVD-Core-rg')
param adfName string

@description('Resource ID of existing Synapse workspace')
param synapseWorkspaceId string

@description('Resource ID of existing ADF')
param adfId string

@description('Managed identity principal ID of existing ADF')
param adfPrincipalId string = ''

@description('Managed identity principal ID of existing Synapse')
param synapsePrincipalId string = ''

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

// --- 1. Networking (VNet, Subnets, NSGs, DNS Zones) -------------------------

module networking 'modules/core-networking.bicep' = {
  name: 'deploy-core-networking'
  scope: rgCore
  params: {
    location: location
  }
}

// --- 2. Security (Key Vault, Log Analytics) ---------------------------------

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
    adfPrincipalId: adfPrincipalId
    synapsePrincipalId: synapsePrincipalId
    // functionAppPrincipalId wired up after RWP module deploys (see below)
  }
}

// --- 4. Security Hardening (Synapse + ADF private endpoints, diagnostics) ---

module hardening 'modules/security-hardening.bicep' = {
  name: 'deploy-security-hardening'
  scope: rgCore
  params: {
    location: location
    logAnalyticsId: security.outputs.logAnalyticsId
    snetPrivateEndpointsId: networking.outputs.snetPrivateEndpointsId
    dnsZoneSqlId: networking.outputs.dnsZoneIds.sql
    dnsZoneAdfId: networking.outputs.dnsZoneIds.adf
    synapseWorkspaceId: synapseWorkspaceId
    synapseWorkspaceName: synapseWorkspaceName
    adfId: adfId
    adfName: adfName
  }
}

// =============================================================================
// RWP RESOURCE GROUP DEPLOYMENT
// =============================================================================

// --- 5. Function App --------------------------------------------------------

module rwpApp 'modules/rwp-function-app.bicep' = {
  name: 'deploy-rwp-function-app'
  scope: rgRwp
  params: {
    location: location
    logAnalyticsId: security.outputs.logAnalyticsId
    snetFunctionsId: networking.outputs.snetFunctionsId
    synapseEndpoint: '${synapseWorkspaceName}-ondemand.sql.azuresynapse.net'
  }
}

// =============================================================================
// POST-DEPLOYMENT: Grant Function App RBAC on ADLS
// =============================================================================

// Standalone RBAC module -- only creates the role assignment, doesn't
// re-deploy the entire ADLS module. Safe to run repeatedly (idempotent).
module funcAdlsRbac 'modules/rbac-assignment.bicep' = {
  name: 'deploy-func-adls-rbac'
  scope: rgCore
  dependsOn: [ adls, rwpApp ]
  params: {
    storageAccountName: adls.outputs.storageAccountName
    principalId: rwpApp.outputs.functionAppPrincipalId
    roleDefinitionId: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' // Storage Blob Data Reader
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

output functionAppHostName string = rwpApp.outputs.functionAppDefaultHostName
output functionAppName string = rwpApp.outputs.functionAppName
output functionAppPrincipalId string = rwpApp.outputs.functionAppPrincipalId
output adlsStorageAccountName string = adls.outputs.storageAccountName
output logAnalyticsName string = security.outputs.logAnalyticsName
output keyVaultName string = security.outputs.keyVaultName
output vnetName string = networking.outputs.vnetName
