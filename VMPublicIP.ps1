# This Script creates an Azure Policy definition to prevent the creation of virtual machines with public IP addresses.
# It uses the Azure PowerShell module to define the policy rule and create the policy definition in the specified subscription.

$policyName = "PreventCreationOfVMWithPublicIP"
$policyDisplayName = "Prevent creation of VM with public IP v5"
$policyDescription = "This policy prevents the creation of virtual machines with public IP addresses."

$policyRule = '{
    "if": {
      "allOf": [
        {
          "field": "type",
          "equals": "Microsoft.Network/networkInterfaces"
        },
        {
          "field": "Microsoft.Network/networkInterfaces/ipConfigurations[*].publicIpAddress.id",
          "exists": "true"
        }
      },        "field": "type",
        "equals": "Microsoft.Compute/virtualMachines"
      },
      {
        "field": "Microsoft.Compute/virtualMachines/networkProfile.networkInterfaceConfigurations[*].ipConfigurations[*].publicIPAddressConfiguration",
        "exists": "true"
      },
    ]
    },

    "then": {
      "effect": "deny"
    }
  }
}'
# Create the policy definition

New-AzPolicyDefinition -Name $policyName -DisplayName $policyDisplayName -Description $policyDescription -Policy $policyRule