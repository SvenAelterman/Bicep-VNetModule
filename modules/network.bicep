param vnetName string
param location string
/*
  Object Schema
  subnet-name: {
    addressPrefix: string (required)
    serviceEndpoints: array
    securityRules: array (optional; if ommitted, no NSG will be created. If [], a default NSG will be created.)
    routes: array (optional; if ommitted, no route table will be created. If [], an empty route table will be created.)
    delegation: string (optional, can be ommitted or be empty string)
  }
*/
@description('A custom object defining the subnet properties of each subnet. { subnet-name: { addressPrefix: string, serviceEndpoints: [], securityRules: [], routes: [], delegation: string } }')
param subnetDefs object
param namingStructure string

@description('Provide a name for the deployment. Optionally, leave an \'{rtype}\' placeholder, which will be replaced with the common resource abbreviation for Virtual Network.')
param deploymentNameStructure string

@description('A IPv4 or IPv6 address space in CIDR notation.')
param vnetAddressPrefix string

param tags object = {}

// Create a network security group for each subnet that requires one
module networkSecurityModule 'networkSecurity.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'networkSecurity'), 64)
  params: {
    subnetDefs: subnetDefs
    deploymentNameStructure: deploymentNameStructure
    namingStructure: namingStructure
    location: location
    tags: tags
  }
}

var nsgIds = reduce(networkSecurityModule.outputs.nsgIds, {}, (cur, next) => union(cur, next))

// Create a route table for each subnet that requires one
module networkRoutingModule 'networkRouting.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'networkRouting'), 64)
  params: {
    deploymentNameStructure: deploymentNameStructure
    namingStructure: namingStructure
    subnetDefs: subnetDefs
    location: location
    tags: tags
  }
}

var routeTableIds = reduce(networkRoutingModule.outputs.routeTableIds, {}, (cur, next) => union(cur, next))

// This is the parent module to deploy a VNet with subnets and output the subnets with their IDs as a custom object
module vnetModule 'vnet.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'vnet')
  params: {
    location: location
    subnetDefs: subnetDefs
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    networkSecurityGroups: nsgIds
    routeTables: routeTableIds
    tags: tags
  }
}

output createdSubnets object = reduce(vnetModule.outputs.actualSubnets, {}, (cur, next) => union(cur, next))

// For demonstration purposes only - this is not used (or usable, probably)
output vnetModuleOutput array = vnetModule.outputs.actualSubnets
