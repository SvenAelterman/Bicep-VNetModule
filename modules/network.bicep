param vnetName string
param location string
param subnetDefs object
param deploymentNameStructure string
param vnetAddressPrefix string

param tags object = {}

// This is the parent module to deploy a VNet with subnets and output the subnets with their IDs as a custom object
module vnetModule 'vnet.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'vnet')
  params: {
    location: location
    subnetDefs: subnetDefs
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    tags: tags
  }
}

output createdSubnets object = reduce(vnetModule.outputs.actualSubnets, {}, (cur, next) => union(cur, next))
// For demonstration purposes only - this is not used (or usable, probably)
output vnetModuleOutput array = vnetModule.outputs.actualSubnets
