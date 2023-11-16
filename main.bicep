targetScope = 'subscription'

@allowed([
  'eastus2'
  'eastus'
])
param location string
@allowed([
  'test'
  'demo'
  'prod'
])
param environment string
param workloadName string

// Optional parameters
param tags object = {}
param sequence int = 1
param namingConvention string = '{wloadname}-{env}-{rtype}-{loc}-{seq}'
param deploymentTime string = utcNow()
@minLength(1)
param vnetAddressPrefixes array = [ '10.0.0.0/16', '10.2.0.0/16' ]
param customDnsIPs array = []
@description('The definition of additional subnets that have been manually created. Uses the ARM schema for subnets.')
param additionalSubnets array

param includeAppGwSubnet bool = true
param deploySampleAppSerice bool = false
param testPeering bool = true

var sequenceFormatted = format('{0:00}', sequence)
var deploymentNameStructure = '${workloadName}-${environment}-{rtype}-${deploymentTime}'

// Naming structure only needs the resource type ({rtype}) replaced
var namingStructure = replace(replace(replace(replace(namingConvention, '{env}', environment), '{loc}', location), '{seq}', sequenceFormatted), '{wloadname}', workloadName)

/*
  Object Schema
  NameOfSubnet: {
    addressPrefix: string (required)
    serviceEndpoints: array (optional)
    securityRules: array (optional; if ommitted, no NSG will be created. If [], a default NSG will be created.)
    routes: array (optional; if ommitted, no route table will be created. If [], an empty route table will be created.)
    delegation: string (optional, can be ommitted or be empty string)
  }
*/
var subnetDefs = {
  ComputeSubnet: {
    addressPrefix: cidrSubnet(vnetAddressPrefixes[0], 24, 0)
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.Sql'
        locations: [
          location
        ]
      }
    ]
    // Omit the securityRules property here so a network security group is not created or assigned
    //securityRules: []
    // Omit the delegation property here
    //delegation: ''
    // Create an empty route table
    routes: []
  }
  AppServiceSubnet: {
    addressPrefix: cidrSubnet(vnetAddressPrefixes[0], 24, 1)
    serviceEndpoints: []
    // Specify an empty array of security rules. Network security group for this subnet will be created, but only contain default rules.
    securityRules: []
    // Delegate this subnet to App Service
    delegation: 'Microsoft.Web/serverFarms'
    // Omit the routes property here
    // routes: []
  }
}

var appGwSubnet = includeAppGwSubnet ? {
  ApplicationGatewaySubnet: {
    addressPrefix: cidrSubnet(vnetAddressPrefixes[0], 24, 255)
    securityRules: []
    // Explicitly specify no delegation of this subnet
    delegation: ''
    // TODO: Pull routes from JSON content files
    routes: [
      {
        name: 'Internet-Direct'
        properties: {
          nextHopType: 'Internet'
          addressPrefix: '0.0.0.0/0'
        }
      }
    ]
  }
} : {}

var subnetsToDeploy = union(subnetDefs, appGwSubnet)

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: replace(namingStructure, '{rtype}', 'rg')
  location: location
  tags: tags
}

module networkModule 'modules/networking/network.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'network'), 64)
  scope: rg
  params: {
    deploymentNameStructure: deploymentNameStructure
    namingStructure: namingStructure
    location: location
    tags: tags
    subnetDefs: subnetsToDeploy
    additionalSubnets: additionalSubnets
    customDnsIPs: customDnsIPs
    vnetAddressPrefixes: map(vnetAddressPrefixes, p => replace(p, '{octet3}', '0'))
  }
}

module network2Module 'modules/networking/network.bicep' = if (testPeering) {
  name: take(replace(deploymentNameStructure, '{rtype}', 'network2'), 64)
  scope: rg
  params: {
    location: location
    deploymentNameStructure: replace(deploymentNameStructure, workloadName, '${workloadName}2')
    namingStructure: replace(namingStructure, workloadName, '${workloadName}2')
    // Don't need subnets just to test peering functionality
    subnetDefs: {}
    vnetAddressPrefixes: [ '10.1.0.0/16' ]
    tags: tags
    remoteVNetResourceId: networkModule.outputs.vNetId
    remoteVNetFriendlyName: 'network1'
    vnetFriendlyName: 'network2'
  }
}

// Can use the output object of networkModule here to get properties from specific subnets by name

// E.g., create an app service with vnet integration
module appServiceModule 'modules/samples/appService.bicep' = if (deploySampleAppSerice) {
  name: replace(deploymentNameStructure, '{rtype}', 'appService')
  scope: rg
  params: {
    location: location
    namingStructure: namingStructure
    tags: tags
    // 'appservice' is the name of the subnet, as defined in the custom object above
    subnetId: networkModule.outputs.createdSubnets.appservice.id
  }
}

output createdSubnets object = networkModule.outputs.createdSubnets
output vNetModuleOutput array = networkModule.outputs.vNetModuleSubnetsOutput
