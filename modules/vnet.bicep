param location string
param vnetName string
param subnetDefs object
param vnetAddressPrefix string

param tags object = {}
var subnetDefsArray = items(subnetDefs)

resource vnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [for (subnet, i) in subnetDefsArray: {
      name: subnet.key
      properties: {
        addressPrefix: subnet.value.addressPrefix
        serviceEndpoints: subnet.value.serviceEndpoints
        delegations: empty(subnet.value.delegation) ? null : [
          {
            name: 'delegation'
            properties: {
              serviceName: subnet.value.delegation
            }
          }
        ]
      }
    }]
  }
  tags: tags
}

// Outputs in the order of subnetDefsArray (alphabetically by subnet name)
// TODO: Is it guaranteed that the order of the subnets in the virtual network is the same as passed in?
// Prior experience suggests this might not always be the case.
output actualSubnets array = [for (subnet, i) in subnetDefsArray: {
  '${subnet.key}': {
    id: vnet.properties.subnets[i].id
    addressPrefix: vnet.properties.subnets[i].properties.addressPrefix
  }
}]
