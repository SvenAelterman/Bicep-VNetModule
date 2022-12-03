# Bicep Virtual Network and Subnets Demo

Demonstrates how to define a network and its subnets and then retrieve the subnets' properties (e.g., `id`) by the name of the subnet.

## Usage

### main.bicep

This is the template that will be deployed. It defines the subnets that will be created in the virtual network.

### deploy.ps1

This PowerShell script will deploy your main.bicep template.

### modules

Contains the modules for the sample to deploy.

#### network.bicep

Calls the virtual network module, but crucially takes the array output of the virtual network module and reduces it so it comes out as an object instead of an array.

`reduce(vnetModule.outputs.actualSubnets, {}, (cur, next) => union(cur, next))`

The output after the reduce function looks like this:

```json
{
 "appservice": {
  "id": "/subscriptions/<id>/resourceGroups/rg-bicepvnet-test-eastus-01/providers/Microsoft.Network/virtualNetworks/vnet-bicepvnet-test-eastus-01/subnets/appservice",
  "addressPrefix": "10.0.1.0/24"
 },
 "compute": {
  "id": "/subscriptions/<id>/resourceGroups/rg-bicepvnet-test-eastus-01/providers/Microsoft.Network/virtualNetworks/vnet-bicepvnet-test-eastus-01/subnets/compute",
  "addressPrefix": "10.0.0.0/24"
 }
}
```

You can see how this can be used (in main.bicep) to extract a subnet's id by the subnet name, as such:

`networkModule.outputs.createdSubnets.appservice.id`

#### vnet.bicep

This module creates the virtual network and its subnets. Subnets are created in a for loop inside the virtual network definition. To use the subnetDefs object in a loop, I must use the items(subnetDefs) function. This will alphabetically sort the subnets by name and not retain the original order in which they were defined in main.bicep. However, I don't think that's relevant, because we want to use the name of the subnet and not its index to use it later.

The output of this module is an array of custom objects, each of which has a single property with the name of the subnet:

```json
[
 {
  "appservice": {
   "id": "/subscriptions/e781198c-6f6d-4994-b688-6e8e34c63c79/resourceGroups/rg-bicepvnet-test-eastus-01/providers/Microsoft.Network/virtualNetworks/vnet-bicepvnet-test-eastus-01/subnets/appservice",
   "addressPrefix": "10.0.1.0/24"
  }
 },
 {
  "compute": {
   "id": "/subscriptions/e781198c-6f6d-4994-b688-6e8e34c63c79/resourceGroups/rg-bicepvnet-test-eastus-01/providers/Microsoft.Network/virtualNetworks/vnet-bicepvnet-test-eastus-01/subnets/compute",
   "addressPrefix": "10.0.0.0/24"
  }
 }
]
```

You can now see how using the reduce function will reduce this array to a custom object which will have as many properties as there are subnets.

## Parameters

Here are the common parameters defined by the template main.bicep:

* **location**: The Azure region to target for deployments.
* **environment**: An environment value, such as "dev."
* **workloadName**: The name of the workload to be deployed. This will be used to name deployments and to complete the naming convention.
* **sequence** (optional, defaults to `1`)
* **tags** (optional, defaults to none)
* **namingConvention** (optional, defaults to `{rtype}-{wloadname}-{env}-{loc}-{seq}`): the structure of the Azure resources names. Use placeholders as follows:
  * **{rtype}**: The resource type. Your main.bicep should replace {rtype} with the recommended Azure resource type abbreviation as found at <https://docs.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations>.
  * **{wloadname}**: Replaced with the value of the `workloadName` parameter.
  * **{env}**: Replaced with the value of the `environment` parameter.
  * **{loc}**: Replaced with the value of the `location` parameter.
  * **{seq}**: Replaced with the string value of the sequence parameter, always formatted as two digits.

These parameters are passed to the deployment from the PowerShell script using the `$Parameters` object, which uses parameter splatting for increased resilience.
