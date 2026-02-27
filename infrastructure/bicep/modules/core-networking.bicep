// =============================================================================
// Core Networking: VNet, Subnets, NSGs, Private DNS Zones
// Deployed to: MVD-Core-rg
// =============================================================================

param location string
param vnetName string = 'mvd-core-vnet'

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

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [ '10.1.0.0/16' ]
    }
    subnets: [
      {
        name: 'snet-private-endpoints'
        properties: {
          addressPrefix: '10.1.1.0/24'
          networkSecurityGroup: { id: nsgPrivateEndpoints.id }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-adf-ir'
        properties: {
          addressPrefix: '10.1.2.0/24'
        }
      }
      {
        name: 'snet-functions'
        properties: {
          addressPrefix: '10.1.3.0/24'
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
        name: 'snet-apps'
        properties: {
          addressPrefix: '10.1.4.0/24'
        }
      }
    ]
  }
}

// --- Private DNS Zones ------------------------------------------------------

var dnsZoneNames = [
  'privatelink.blob.core.windows.net'
  'privatelink.dfs.core.windows.net'
  'privatelink.sql.azuresynapse.net'
  'privatelink.datafactory.azure.net'
  'privatelink.vaultcore.azure.net'
  'privatelink.azurewebsites.net'
]

resource dnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [
  for zone in dnsZoneNames: {
    name: zone
    location: 'global'
  }
]

resource dnsVnetLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [
  for (zone, i) in dnsZoneNames: {
    parent: dnsZones[i]
    name: '${replace(zone, '.', '-')}-link'
    location: 'global'
    properties: {
      virtualNetwork: { id: vnet.id }
      registrationEnabled: false
    }
  }
]

// --- Outputs ----------------------------------------------------------------

output vnetId string = vnet.id
output vnetName string = vnet.name
output snetPrivateEndpointsId string = vnet.properties.subnets[0].id
output snetAdfIrId string = vnet.properties.subnets[1].id
output snetFunctionsId string = vnet.properties.subnets[2].id
output snetAppsId string = vnet.properties.subnets[3].id
output dnsZoneIds object = {
  blob: dnsZones[0].id
  dfs: dnsZones[1].id
  sql: dnsZones[2].id
  adf: dnsZones[3].id
  vault: dnsZones[4].id
  websites: dnsZones[5].id
}
