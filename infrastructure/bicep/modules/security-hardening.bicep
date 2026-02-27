// =============================================================================
// Security Hardening: Private endpoints + monitoring alerts for Synapse and ADF
// Deployed to: MVD-Core-rg
//
// Note: Diagnostic settings for Synapse and ADF are co-located in their
// respective modules (synapse.bicep, adf.bicep). This module handles only
// private endpoints and metric alerts.
// =============================================================================

param location string
param snetPrivateEndpointsId string
param dnsZoneSqlId string
param dnsZoneAdfId string

param synapseWorkspaceId string
param synapseWorkspaceName string
param adfId string
param adfName string

// =============================================================================
// SYNAPSE PRIVATE ENDPOINT
// =============================================================================

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

// =============================================================================
// ADF PRIVATE ENDPOINT
// =============================================================================

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

// =============================================================================
// MONITORING ALERTS
// =============================================================================

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
