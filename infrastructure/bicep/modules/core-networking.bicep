// =============================================================================
// Core Networking: Add subnets to existing VNet, create missing DNS Zones
// Deployed to: MVD-Core-rg
//
// References existing:
//   - VNet: vnet-miravista-core (10.102.0.0/16)
//   - Subnet: snet-private-endpoints (10.102.1.0/24)
//   - DNS Zones: blob, vault, websites (with existing VNet links)
//
// Creates new:
//   - Subnets: snet-functions, snet-adf-ir, snet-apps
//   - DNS Zones: dfs, sql, adf (with VNet links)
//   - NSG for functions subnet
// =============================================================================

param location string
param vnetName string = 'vnet-miravista-core'

// --- Reference Existing VNet + Subnet ----------------------------------------

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
}

resource snetPrivateEndpoints 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: vnet
  name: 'snet-private-endpoints'
}

// --- NSG for Functions Subnet ------------------------------------------------

resource nsgFunctions 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-functions'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPSInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          destinationPortRange: '443'
        }
      }
    ]
  }
}

// --- New Subnets (added to existing VNet) ------------------------------------
// Deployed sequentially to avoid ARM VNet lock contention

resource snetFunctions 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: vnet
  name: 'snet-functions'
  properties: {
    addressPrefix: '10.102.2.0/24'
    networkSecurityGroup: { id: nsgFunctions.id }
    delegations: [
      {
        name: 'delegation-web'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
  }
}

resource snetAdfIr 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: vnet
  name: 'snet-adf-ir'
  dependsOn: [ snetFunctions ] // Serialize subnet operations
  properties: {
    addressPrefix: '10.102.3.0/24'
  }
}

resource snetApps 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: vnet
  name: 'snet-apps'
  dependsOn: [ snetAdfIr ] // Serialize subnet operations
  properties: {
    addressPrefix: '10.102.4.0/24'
  }
}

// --- Reference Existing DNS Zones --------------------------------------------

resource dnsZoneBlob 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.blob.core.windows.net'
}

resource dnsZoneVault 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.vaultcore.azure.net'
}

resource dnsZoneWebsites 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.azurewebsites.net'
}

// --- Create Missing DNS Zones ------------------------------------------------

resource dnsZoneDfs 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.dfs.core.windows.net'
  location: 'global'
}

resource dnsZoneSql 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.sql.azuresynapse.net'
  location: 'global'
}

resource dnsZoneAdf 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.datafactory.azure.net'
  location: 'global'
}

// VNet links for new DNS zones only (existing zones already have links)

resource dfsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: dnsZoneDfs
  name: 'link-${vnetName}'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnet.id }
    registrationEnabled: false
  }
}

resource sqlVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: dnsZoneSql
  name: 'link-${vnetName}'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnet.id }
    registrationEnabled: false
  }
}

resource adfVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: dnsZoneAdf
  name: 'link-${vnetName}'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnet.id }
    registrationEnabled: false
  }
}

// --- Outputs ----------------------------------------------------------------

output vnetId string = vnet.id
output vnetName string = vnet.name
output snetPrivateEndpointsId string = snetPrivateEndpoints.id
output snetFunctionsId string = snetFunctions.id
output snetAdfIrId string = snetAdfIr.id
output snetAppsId string = snetApps.id
output dnsZoneIds object = {
  blob: dnsZoneBlob.id
  dfs: dnsZoneDfs.id
  sql: dnsZoneSql.id
  adf: dnsZoneAdf.id
  vault: dnsZoneVault.id
  websites: dnsZoneWebsites.id
}
