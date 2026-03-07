// =============================================================================
// RWP Function App: Function App, ASP, App Insights, Storage, VNet Integration
// Deployed to: rg-rwp-cus-001
// =============================================================================

param location string
param functionAppName string = 'func-rwp-cus-001'
param appServicePlanName string = 'asp-rwp-cus-001'
param storageAccountName string = 'strwpcus001'
param appInsightsName string = 'appi-rwp-cus-001'

// Cross-RG references
param logAnalyticsId string
param snetFunctionsId string
param synapseEndpoint string = ''

// Entra ID (Azure AD) App Registration — create manually, then set these params
@description('Entra ID App Registration client ID for EasyAuth')
param entraClientId string = ''
@description('Entra ID tenant ID')
param entraTenantId string = ''

// Security group Object IDs for report-level authorization
@description('Object ID of sg-rwp-ePHI-Users security group (full RWP with PII)')
param ephiGroupId string = ''
@description('Object ID of sg-rwp-CFO-Users security group (RWPCFO without PII)')
param cfoGroupId string = ''

// --- Function App Storage Account -------------------------------------------

resource funcStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
  }
}

// --- Application Insights ---------------------------------------------------

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsId
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// --- App Service Plan (Elastic Premium for VNet integration) ----------------

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
  }
  properties: {
    reserved: true // Linux
    maximumElasticWorkerCount: 3
  }
}

// --- Function App -----------------------------------------------------------

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    virtualNetworkSubnetId: snetFunctionsId
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11'
      pythonVersion: '3.11'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      vnetRouteAllEnabled: true
      cors: {
        allowedOrigins: [
          'https://${functionAppName}.azurewebsites.net'
          'https://localhost:3000'
        ]
        supportCredentials: true
      }
      appSettings: [
        { name: 'AzureWebJobsStorage', value: 'DefaultEndpointsProtocol=https;AccountName=${funcStorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${funcStorage.listKeys().keys[0].value}' }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'python' }
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsights.properties.ConnectionString }
        { name: 'APPINSIGHTS_INSTRUMENTATIONKEY', value: appInsights.properties.InstrumentationKey }
        { name: 'SCM_DO_BUILD_DURING_DEPLOYMENT', value: 'true' }
        { name: 'WEBSITE_VNET_ROUTE_ALL', value: '1' }
        { name: 'SYNAPSE_ENDPOINT', value: synapseEndpoint }
        { name: 'SYNAPSE_DATABASE', value: 'rwp_analytics' }
        { name: 'RWP_EPHI_GROUP_ID', value: ephiGroupId }
        { name: 'RWP_CFO_GROUP_ID', value: cfoGroupId }
      ]
    }
  }
}

// --- Entra ID (EasyAuth) Authentication ------------------------------------

resource authSettings 'Microsoft.Web/sites/config@2023-12-01' = if (!empty(entraClientId)) {
  name: 'authsettingsV2'
  parent: functionApp
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'RedirectToLoginPage'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: entraClientId
          openIdIssuer: 'https://sts.windows.net/${entraTenantId}/v2.0'
        }
        validation: {
          allowedAudiences: [
            'api://${entraClientId}'
          ]
        }
      }
    }
    login: {
      tokenStore: {
        enabled: true
      }
      allowedExternalRedirectUrls: [
        'https://${functionAppName}.azurewebsites.net'
        'https://localhost:3000'
      ]
      cookieExpiration: {
        convention: 'FixedTime'
        timeToExpiration: '08:00:00'
      }
      nonce: {
        validateNonce: true
      }
    }
  }
}

// --- Diagnostic Settings ----------------------------------------------------

resource funcDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${functionAppName}'
  scope: functionApp
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

// --- Monitoring Alerts ------------------------------------------------------

resource alertErrors 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-rwp-cus-001-errors'
  location: 'global'
  properties: {
    severity: 2
    enabled: true
    scopes: [ functionApp.id ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Http5xx'
          metricName: 'Http5xx'
          metricNamespace: 'Microsoft.Web/sites'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    description: 'RWP Function App HTTP 5xx errors exceeded threshold'
  }
}

resource alertLatency 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-rwp-cus-001-latency'
  location: 'global'
  properties: {
    severity: 3
    enabled: true
    scopes: [ functionApp.id ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HttpResponseTime'
          metricName: 'HttpResponseTime'
          metricNamespace: 'Microsoft.Web/sites'
          operator: 'GreaterThan'
          threshold: 10
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    description: 'RWP Function App avg response time > 10s'
  }
}

// --- Outputs ----------------------------------------------------------------

output functionAppPrincipalId string = functionApp.identity.principalId
output functionAppName string = functionApp.name
output functionAppDefaultHostName string = functionApp.properties.defaultHostName
