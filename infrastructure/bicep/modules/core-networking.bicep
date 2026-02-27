// =============================================================================
// Core Networking: New VNet in IPAM-compliant Central US Shared Services range,
// subnets, NSGs, and Private DNS Zones
// Deployed to: MVD-Core-rg
//
// IPAM Allocation:
//   VNet: 10.118.0.0/22 (Central US > Workload Services > Shared Services)
//   snet-private-endpoints:  10.118.0.0/24
//   snet-functions:          10.118.1.0/24  (delegated to Microsoft.Web)
//   snet-adf-ir:             10.118.2.0/24
//   snet-apps:               10.118.3.0/24
//
// DNS Zones:
//   Existing (add VNet link): blob, vault, websites
//   New (create + link):      dfs, sql, adf
//
// Note: VNet peering with vnet-hub-core is required for on-premises
// connectivity via vpngw-hub-core. This should be handled by the
// platform/connectivity team after deployment.
// =============================================================================

param location string
param vnetName string = 'vnet-mvd-cus-001'

// --- NSGs -------------------------------------------------------------------

resource nsgPrivateEndpoints 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-private-endpoints'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowVNetInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

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

// --- VNet + Subnets ---------------------------------------------------------
// 10.118.0.0/22 = Central US, Shared Services (IPAM-compliant)

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [ '10.118.0.0/22' ]
    }
    subnets: [
      {
        name: 'snet-private-endpoints'
        properties: {
          addressPrefix: '10.118.0.0/24'
          networkSecurityGroup: { id: nsgPrivateEndpoints.id }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-functions'
        properties: {
          addressPrefix: '10.118.1.0/24'
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
      {
        name: 'snet-adf-ir'
        properties: {
          addressPrefix: '10.118.2.0/24'
        }
      }
      {
        name: 'snet-apps'
        properties: {
          addressPrefix: '10.118.3.0/24'
        }
      }
    ]
  }
}

// --- Private DNS Zones ------------------------------------------------------
// Existing zones: add VNet link to the new VNet
// New zones: create zone + VNet link

// Reference existing DNS zones (already in MVD-Core-rg)
resource dnsZoneBlob 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.blob.core.windows.net'
}

resource dnsZoneVault 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.vaultcore.azure.net'
}

resource dnsZoneWebsites 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.azurewebsites.net'
}

// Add VNet links from existing DNS zones to the new VNet
resource blobVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: dnsZoneBlob
  name: 'link-${vnetName}'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnet.id }
    registrationEnabled: false
  }
}

resource vaultVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: dnsZoneVault
  name: 'link-${vnetName}'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnet.id }
    registrationEnabled: false
  }
}

resource websitesVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: dnsZoneWebsites
  name: 'link-${vnetName}'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnet.id }
    registrationEnabled: false
  }
}

// Create new DNS zones + VNet links
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
output snetPrivateEndpointsId string = vnet.properties.subnets[0].id
output snetFunctionsId string = vnet.properties.subnets[1].id
output snetAdfIrId string = vnet.properties.subnets[2].id
output snetAppsId string = vnet.properties.subnets[3].id
output dnsZoneIds object = {
  blob: dnsZoneBlob.id
  dfs: dnsZoneDfs.id
  sql: dnsZoneSql.id
  adf: dnsZoneAdf.id
  vault: dnsZoneVault.id
  websites: dnsZoneWebsites.id
}
