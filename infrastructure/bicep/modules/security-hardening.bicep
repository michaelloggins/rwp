// =============================================================================
// Security Hardening: Private endpoints + diagnostics for existing
// Synapse and ADF resources, plus monitoring alerts.
// Deployed to: MVD-Core-rg
// =============================================================================

param location string
param logAnalyticsId string
param snetPrivateEndpointsId string
param dnsZoneSqlId string
param dnsZoneAdfId string

// Existing resource IDs (these resources are already deployed)
param synapseWorkspaceId string
param synapseWorkspaceName string
param adfId string
param adfName string

// =============================================================================
// SYNAPSE
// =============================================================================

// --- Private Endpoint (SqlOnDemand / Serverless) ---

resource synapsePe 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${synapseWorkspaceName}-sql'
  location: location
  properties: {
    subnet: { id: snetPrivateEndpointsId }
    privateLinkServiceConnections: [
      {
        name: 'pec-${synapseWorkspaceName}-sql'
        properties: {
          privateLinkServiceId: synapseWorkspaceId
          groupIds: [ 'SqlOnDemand' ]
        }
      }
    ]
  }
}

resource synapsePeDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: synapsePe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'synapse-sql'
        properties: { privateDnsZoneId: dnsZoneSqlId }
      }
    ]
  }
}

// --- Synapse Diagnostics ---

resource synapseDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${synapseWorkspaceName}'
  scope: synapseWorkspace
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

// Reference existing Synapse for diagnostic scope
resource synapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01' existing = {
  name: synapseWorkspaceName
}

// =============================================================================
// ADF
// =============================================================================

// --- Private Endpoint ---

resource adfPe 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${adfName}-df'
  location: location
  properties: {
    subnet: { id: snetPrivateEndpointsId }
    privateLinkServiceConnections: [
      {
        name: 'pec-${adfName}-df'
        properties: {
          privateLinkServiceId: adfId
          groupIds: [ 'dataFactory' ]
        }
      }
    ]
  }
}

resource adfPeDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: adfPe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'adf'
        properties: { privateDnsZoneId: dnsZoneAdfId }
      }
    ]
  }
}

// --- ADF Diagnostics ---

resource adfResource 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: adfName
}

resource adfDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${adfName}'
  scope: adfResource
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

// =============================================================================
// MONITORING ALERTS
// =============================================================================

// --- ADF Pipeline Failure Alert ---

resource alertAdfFailure 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-adf-pipeline-failure'
  location: 'global'
  properties: {
    severity: 2
    enabled: true
    scopes: [ adfId ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'PipelineFailedRuns'
          metricName: 'PipelineFailedRuns'
          metricNamespace: 'Microsoft.DataFactory/factories'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    description: 'ADF pipeline run failed'
  }
}

// --- Synapse Query Failure Alert ---

resource alertSynapseFailure 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-synapse-query-failure'
  location: 'global'
  properties: {
    severity: 3
    enabled: true
    scopes: [ synapseWorkspaceId ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'BuiltinSqlPoolRequestsEnded'
          metricName: 'BuiltinSqlPoolRequestsEnded'
          metricNamespace: 'Microsoft.Synapse/workspaces'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'Result'
              operator: 'Include'
              values: [ 'Error' ]
            }
          ]
        }
      ]
    }
    description: 'Synapse Serverless query errors detected'
  }
}
