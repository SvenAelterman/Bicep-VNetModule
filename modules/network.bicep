param vnetName string
param location string
param subnetDefs object

@description('Provide a name for the deployment. Optionally, leave an \'{rtype}\' placeholder, which will be replaced with the common resource abbreviation for Virtual Network.')
param deploymentNameStructure string

@description('A IPv4 or IPv6 address space in CIDR notation.')
param vnetAddressPrefix string

param tags object = {}

// TODO: Add Network security group creation, UDR creation; and linking to subnets (from UHealth examples)

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
