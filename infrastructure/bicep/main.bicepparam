using 'main.bicep'

// =============================================================================
// RWP Infrastructure Parameters
//
// The only value NOT in this file is sqlAdministratorLoginPassword.
// Pass it at deploy time:
//   az deployment sub create \
//     --location centralus \
//     --template-file main.bicep \
//     --parameters main.bicepparam \
//     --parameters sqlAdministratorLoginPassword='<secure-password>'
// =============================================================================

param location = 'centralus'
param coreResourceGroup = 'MVD-Core-rg'
param rwpResourceGroup = 'rg-rwp-cus-001'
