using 'main.bicep'

// =============================================================================
// RWP Infrastructure Parameters
// Update these values for your environment before deploying.
// =============================================================================

param location = 'centralus'
param coreResourceGroup = 'MVD-Core-rg'
param rwpResourceGroup = 'rg-rwp-cus-001'

// --- Existing resources (already deployed in MVD-Core-rg) ---
// Get these values from the Azure portal or CLI:
//   az synapse workspace show -n <name> -g MVD-Core-rg --query '{id:id, name:name, principalId:identity.principalId}'
//   az datafactory show -n <name> -g MVD-Core-rg --query '{id:id, name:name, principalId:identity.principalId}'

param synapseWorkspaceName = '<your-synapse-workspace-name>'
param synapseWorkspaceId = '/subscriptions/<sub-id>/resourceGroups/MVD-Core-rg/providers/Microsoft.Synapse/workspaces/<your-synapse-workspace-name>'

param adfName = '<your-adf-name>'
param adfId = '/subscriptions/<sub-id>/resourceGroups/MVD-Core-rg/providers/Microsoft.DataFactory/factories/<your-adf-name>'

// Managed identity principal IDs (for ADLS RBAC)
param adfPrincipalId = '<adf-managed-identity-principal-id>'
param synapsePrincipalId = '<synapse-managed-identity-principal-id>'
