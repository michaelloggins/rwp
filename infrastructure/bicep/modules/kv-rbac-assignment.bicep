// =============================================================================
// Standalone RBAC Role Assignment on Key Vault
// Reusable module for granting a role to a principal on a Key Vault.
// =============================================================================

@description('Key Vault name to scope the role assignment to')
param keyVaultName string

@description('Principal ID to assign the role to')
param principalId string

@description('Role definition ID (just the GUID, not full resource ID)')
@allowed([
  '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
  '00482a5a-887f-4fb3-b363-3b7fe8e74483' // Key Vault Administrator
])
param roleDefinitionId string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, principalId, roleDefinitionId)
  scope: keyVault
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
  }
}
