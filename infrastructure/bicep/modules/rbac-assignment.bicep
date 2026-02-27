// =============================================================================
// Standalone RBAC Role Assignment
// Reusable module for granting a role to a principal on a storage account.
// =============================================================================

@description('Storage account name to scope the role assignment to')
param storageAccountName string

@description('Principal ID to assign the role to')
param principalId string

@description('Role definition ID (just the GUID, not full resource ID)')
@allowed([
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
  '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' // Storage Blob Data Reader
])
param roleDefinitionId string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, principalId, roleDefinitionId)
  scope: storageAccount
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
  }
}
