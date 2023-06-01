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
param vnetAddressPrefix string = '10.0.{octet3}.0'
param vnetCidr string = '16'
param subnetCidr string = '24'
param customDnsIPs array = []
param includeAppGwSubnet bool = true

var sequenceFormatted = format('{0:00}', sequence)
var deploymentNameStructure = '${workloadName}-${environment}-{rtype}-${deploymentTime}'

// Naming structure only needs the resource type ({rtype}) replaced
var namingStructure = replace(replace(replace(replace(namingConvention, '{env}', environment), '{loc}', location), '{seq}', sequenceFormatted), '{wloadname}', workloadName)

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
var subnetDefs = {
  compute: {
    addressPrefix: '${replace(vnetAddressPrefix, '{octet3}', '0')}/${subnetCidr}'
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
  appservice: {
    addressPrefix: '${replace(vnetAddressPrefix, '{octet3}', '1')}/${subnetCidr}'
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
  appGw: {
    addressPrefix: '${replace(vnetAddressPrefix, '{octet3}', '255')}/${subnetCidr}'
    securityRules: []
    // Explicitly specify no delegation of this subnet
    delegation: ''
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
  name: replace(deploymentNameStructure, '{rtype}', 'network')
  scope: rg
  params: {
    deploymentNameStructure: deploymentNameStructure
    namingStructure: namingStructure
    location: location
    tags: tags
    subnetDefs: subnetsToDeploy
    customDnsIPs: customDnsIPs
    vnetAddressPrefix: '${replace(vnetAddressPrefix, '{octet3}', '0')}/${vnetCidr}'
  }
}

// Can use the output object of networkModule here to get properties from specific subnets by name

// E.g., create an app service with vnet integration
module appServiceModule 'modules/samples/appService.bicep' = {
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
