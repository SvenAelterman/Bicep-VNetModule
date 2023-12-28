# PowerShell script to deploy the main.bicep template with parameter values

#Requires -Modules "Az"
#Requires -PSEdition Core

# Use these parameters to customize the deployment instead of modifying the default parameter values
[CmdletBinding()]
Param(
	[ValidateSet('eastus2', 'eastus')]
	[string]$Location = 'eastus',
	# The environment descriptor
	[ValidateSet('test', 'demo', 'prod')]
	[string]$Environment = 'test',
	[string]$WorkloadName = 'bicepvnet',
	[int]$Sequence = 1
)

$TemplateParameters = @{
	# REQUIRED
	location          = $Location
	environment       = $Environment
	workloadName      = $WorkloadName
	customDnsIPs      = @()

	additionalSubnets = @(
		@{
			name       = 'ApplicationGateway2Subnet'
			properties = @{
				addressPrefix        = '10.0.2.0/24'
				networkSecurityGroup = @{
					id = '/subscriptions/05bca35e-0dfa-455a-a4eb-9f9ea72df723/resourceGroups/bicepvnet-test-rg-eastus-01/providers/Microsoft.Network/networkSecurityGroups/sample-test-nsg-eastus-01'
				}
				routeTable           = @{
					id = '/subscriptions/05bca35e-0dfa-455a-a4eb-9f9ea72df723/resourceGroups/bicepvnet-test-rg-eastus-01/providers/Microsoft.Network/routeTables/sample-test-rt-eastus-01'
				}
				delegations          = @()
			}
		}
	)

	# OPTIONAL
	sequence          = $Sequence
	#namingConvention = $NamingConvention
	tags              = @{
		'date-created' = (Get-Date -Format 'yyyy-MM-dd')
		purpose        = $Environment
		lifetime       = 'short'
	}
}

$DeploymentResult = New-AzDeployment -Location $Location -Name "$WorkloadName-$Environment-$(Get-Date -Format 'yyyyMMddThhmmssZ' -AsUTC)" `
	-TemplateFile ".\main.bicep" -TemplateParameterObject $TemplateParameters

$DeploymentResult

if ($DeploymentResult.ProvisioningState -eq 'Succeeded') {
	Write-Host "🔥 Deployment successful"
}
