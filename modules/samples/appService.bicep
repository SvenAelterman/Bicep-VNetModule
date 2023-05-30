param location string
param namingStructure string

// Optionally integrate with a virtual network
param subnetId string = ''
param tags object = {}

resource plan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: replace(namingStructure, '{rtype}', 'plan')
  location: location
  sku: {
    name: 'S1'
    size: 'Standard'
  }
  tags: tags
}

resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: replace(namingStructure, '{rtype}', 'asp')
  location: location
  properties: {
    serverFarmId: plan.id
    virtualNetworkSubnetId: empty(subnetId) ? null : subnetId
    vnetRouteAllEnabled: true
  }
  tags: tags
}
