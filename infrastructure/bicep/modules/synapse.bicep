// =============================================================================
// Synapse Serverless Workspace
// Deployed to: MVD-Core-rg
//
// Creates Synapse workspace with system-assigned managed identity,
// managed VNet, and serverless SQL pool (built-in).
// The managed identity needs Storage Blob Data Contributor on ADLS
// (granted via rbac-assignment module in main.bicep).
// Managed VNet enables managed private endpoints for secure storage access.
// =============================================================================

param location string
param synapseWorkspaceName string = 'syn-mvd-cus-001'
param defaultDataLakeAccountName string
param defaultDataLakeAccountId string
param defaultDataLakeFilesystem string = 'synapse'
param sqlAdministratorLogin string = 'sqladmin'

@secure()
param sqlAdministratorLoginPassword string

param logAnalyticsId string

// --- Synapse Workspace -------------------------------------------------------

resource synapse 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: synapseWorkspaceName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    defaultDataLakeStorage: {
      accountUrl: 'https://${defaultDataLakeAccountName}.dfs.${environment().suffixes.storage}'
      filesystem: defaultDataLakeFilesystem
    }
    managedVirtualNetwork: 'default'
    managedVirtualNetworkSettings: {
      preventDataExfiltration: true
      allowedAadTenantIdsForLinking: []
    }
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorLoginPassword
    publicNetworkAccess: 'Disabled'
  }
}

// Firewall rules removed — public network access is disabled and
// all connectivity goes through private endpoints.

// --- Diagnostics -------------------------------------------------------------

resource synapseDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${synapseWorkspaceName}'
  scope: synapse
  properties: {
    workspaceId: logAnalyticsId
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

output synapseWorkspaceId string = synapse.id
output synapseWorkspaceName string = synapse.name
output synapsePrincipalId string = synapse.identity.principalId
output synapseEndpoint string = '${synapseWorkspaceName}-ondemand.sql.azuresynapse.net'
