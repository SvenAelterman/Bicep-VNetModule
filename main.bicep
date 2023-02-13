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
param namingConvention string = '{rtype}-{wloadname}-{env}-{loc}-{seq}'
param deploymentTime string = utcNow()
param vnetAddressPrefix string = '10.0.{octet3}.0'
param vnetCidr string = '16'
param subnetCidr string = '24'

var sequenceFormatted = format('{0:00}', sequence)
var deploymentNameStructure = '${workloadName}-${environment}-{rtype}-${deploymentTime}'

// Naming structure only needs the resource type ({rtype}) replaced
var namingStructure = replace(replace(replace(replace(namingConvention, '{env}', environment), '{loc}', location), '{seq}', sequenceFormatted), '{wloadname}', workloadName)

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
    delegation: ''
  }
  appservice: {
    addressPrefix: '${replace(vnetAddressPrefix, '{octet3}', '1')}/${subnetCidr}'
    serviceEndpoints: []
    delegation: 'Microsoft.Web/serverFarms'
  }
}

// TODO: Add union example for optional subnets

module networkModule 'modules/network.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'network')
  params: {
    vnetName: replace(namingStructure, '{rtype}', 'vnet')
    deploymentNameStructure: deploymentNameStructure
    location: location
    tags: tags
    subnetDefs: subnetDefs
    vnetAddressPrefix: '${replace(vnetAddressPrefix, '{octet3}', '0')}/${vnetCidr}'
  }
}

// Can use the output object of networkModule here to get properties from specific subnets by name

// E.g., create an app service with vnet integration
module appServiceModule 'modules/appService.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'appService')
  params: {
    location: location
    namingStructure: namingStructure
    tags: tags
    subnetId: networkModule.outputs.createdSubnets.appservice.id
  }
}

output createdSubnets object = networkModule.outputs.createdSubnets
output vnetModuleOutput array = networkModule.outputs.vnetModuleOutput
