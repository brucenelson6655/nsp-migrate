Automation Tools for Migration
Azure Resource Graph (ARG) Query to get a list of storage accounts:
| where type == "microsoft.storage/storageaccounts"
| where array_length(properties.networkAcls.virtualNetworkRules) > 0
| mvexpand properties.networkAcls.virtualNetworkRules
| where properties_networkAcls_virtualNetworkRules.id contains("/subscriptions/{subid}/resourceGroups/{rg}/providers/Microsoft.Network/virtualNetworks/someVNet")
|| project name, id, resourceGroup, subscriptionId, vnetRuleId = tostring(vnr.id), properties
| summarize by id, name
PowerShell Script
# Sign in and set context
Connect-AzAccount
# Set variables
$subscriptionId = "72d2cdcb-dd88-4ef9-a253-fd33245017d5"
$resourceGroup = "brn-common-wus"
$nspName    = "databricks-nsp"
$location    = "westus"
$profileName  = "adb-profile"
 # Select subscription
Select-AzSubscription -SubscriptionId $subscriptionId
 # Query ARG for Storage Accounts with VNet ACLs pointing to Databricks subnets
$kql = @"
resources
| where type == "microsoft.storage/storageaccounts"
| where array_length(properties.networkAcls.virtualNetworkRules) > 0
| mvexpand vnr = properties.networkAcls.virtualNetworkRules
| where vnr.id in ( 
    "/subscriptions/6c0d042c-6733-4420-a3cc-4175d0439b29/resourceGroups/prod-eastus2-snp-1-compute-4/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/6c0d042c-6733-4420-a3cc-4175d0439b29/resourceGroups/prod-westeurope-snp-1-compute-4/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/23a8c420-c354-43f9-91f5-59d08c6b3dff/resourceGroups/prod-eastus-snp-1-compute-2/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/23a8c420-c354-43f9-91f5-59d08c6b3dff/resourceGroups/prod-eastus2-snp-1-compute-2/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/23a8c420-c354-43f9-91f5-59d08c6b3dff/resourceGroups/prod-westeurope-snp-1-compute-2/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/b96a1dc5-559f-4249-a30c-5b5a98023c45/resourceGroups/prod-eastus2-snp-1-compute-7/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/b96a1dc5-559f-4249-a30c-5b5a98023c45/resourceGroups/prod-westeurope-snp-1-compute-7/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/56beece1-dbc8-40ca-8520-e1d514fb2ccc/resourceGroups/prod-eastus-snp-1-compute-8/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/56beece1-dbc8-40ca-8520-e1d514fb2ccc/resourceGroups/prod-eastus2-snp-1-compute-8/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/56beece1-dbc8-40ca-8520-e1d514fb2ccc/resourceGroups/prod-westeurope-snp-1-compute-8/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/31ef391b-7908-48ec-8c74-e432113b607b/resourceGroups/prod-eastus-snp-1-compute-3/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/31ef391b-7908-48ec-8c74-e432113b607b/resourceGroups/prod-eastus2-snp-1-compute-3/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/31ef391b-7908-48ec-8c74-e432113b607b/resourceGroups/prod-westeurope-snp-1-compute-3/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/6c0d042c-6733-4420-a3cc-4175d0439b29/resourceGroups/prod-eastus-snp-1-compute-4/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/d31d7397-093d-4cc4-abd6-28b426c0c882/resourceGroups/prod-eastus-snp-1-compute-9/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/d31d7397-093d-4cc4-abd6-28b426c0c882/resourceGroups/prod-eastus2-snp-1-compute-9/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/d31d7397-093d-4cc4-abd6-28b426c0c882/resourceGroups/prod-westeurope-snp-1-compute-9/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/b4f59749-ad17-4573-95ef-cc4c63a45bdf/resourceGroups/prod-eastus-snp-1-compute-10/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/b4f59749-ad17-4573-95ef-cc4c63a45bdf/resourceGroups/prod-eastus2-snp-1-compute-10/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/b4f59749-ad17-4573-95ef-cc4c63a45bdf/resourceGroups/prod-westeurope-snp-1-compute-10/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/9d5fffc7-7640-44a1-ba2b-f77ada7731d4/resourceGroups/prod-eastus-snp-1-compute-5/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/9d5fffc7-7640-44a1-ba2b-f77ada7731d4/resourceGroups/prod-eastus2-snp-1-compute-5/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/9d5fffc7-7640-44a1-ba2b-f77ada7731d4/resourceGroups/prod-westeurope-snp-1-compute-5/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/653c13e3-a85b-449b-9d14-e3e9c4b0d391/resourceGroups/prod-eastus-snp-1-compute-6/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/653c13e3-a85b-449b-9d14-e3e9c4b0d391/resourceGroups/prod-eastus2-snp-1-compute-6/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/653c13e3-a85b-449b-9d14-e3e9c4b0d391/resourceGroups/prod-westeurope-snp-1-compute-6/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/b96a1dc5-559f-4249-a30c-5b5a98023c45/resourceGroups/prod-eastus-snp-1-compute-7/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/8453a5d5-9e9e-40c7-87a4-0ab4cc197f48/resourceGroups/prod-eastus-snp-1-compute-1/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/8453a5d5-9e9e-40c7-87a4-0ab4cc197f48/resourceGroups/prod-eastus2-snp-1-compute-1/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet",
    "/subscriptions/8453a5d5-9e9e-40c7-87a4-0ab4cc197f48/resourceGroups/prod-westeurope-snp-1-compute-1/providers/Microsoft.Network/virtualNetworks/kaas-vnet/subnets/worker-subnet"
)
| project name, id, resourceGroup, subscriptionId, vnetRuleId = tostring(vnr.id), properties
| summarize by id, name
"@
 $storageAccounts = Search-AzGraph -Query $kql  
Write-Host "Found $($storageAccounts.Count) Storage Accounts with Databricks VNet ACLs"
if ($storageAccounts.Count -eq 0) {
    Write-Host "No Storage Accounts matched—no NSP work required."
    return
}
# Create Resource Group
New-AzResourceGroup -Name $resourceGroup -Location $location
# Create NSP
New-AzNetworkSecurityPerimeter -Name $nspName -ResourceGroupName $resourceGroup -Location $location
 
# Create Profile
$nspProfile = New-AzNetworkSecurityPerimeterProfile -Name $profileName -SecurityPerimeterName $nspName -ResourceGroupName $resourceGroup
 # Create Rule to approve AzureDatabricksServerless
New-AzNetworkSecurityPerimeterAccessRule -Name "Allow-AzureDatabricks-Serverless" `
    -ProfileName $profileName `
    -SecurityPerimeterName $nspName `
    -ResourceGroupName $rgName `
    -Direction Inbound `
    -ServiceTag "AzureDatabricksServerless"
 # Associate all Storage Accounts in transition mode
foreach ($sa in $storageAccounts) {  
    Write-Host "Associating $($sa.name) with NSP in transition mode..."  
    New-AzNetworkSecurityPerimeterAssociation -Name "$($sa.name)-Assoc" -SecurityPerimeterName $nspName -ResourceGroupName $resourceGroup -ProfileId $nspProfile.Id -PrivateLinkResourceId $sa.id -AccessMode 'Learning'  
} 