// =============================================================================
// Azure Data Factory
// Deployed to: MVD-Core-rg
//
// Creates ADF factory with system-assigned managed identity.
// The managed identity needs Storage Blob Data Contributor on ADLS
// (granted via rbac-assignment module in main.bicep).
// =============================================================================

param location string
param adfName string = 'adf-mvd-cus-001'
param logAnalyticsId string

// --- Data Factory ------------------------------------------------------------

resource adf 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: adfName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
  }
}

// --- Diagnostics -------------------------------------------------------------

resource adfDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${adfName}'
  scope: adf
  properties: {
    workspaceId: logAnalyticsId
    logs: [
      { categoryGroup: 'allLogs', enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}

// --- Outputs ----------------------------------------------------------------

output adfId string = adf.id
output adfName string = adf.name
output adfPrincipalId string = adf.identity.principalId
