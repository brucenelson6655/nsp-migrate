$subscriptionId = "72d2cdcb-dd88-4ef9-a253-fd33245017d5"
$resourceGroup = "brn-common-wus"
$nspName    = "mig-databricks-nsp"
$location    = "westus"
$profileName  = "adb-profile"
 # Select subscription
Select-AzSubscription -SubscriptionId $subscriptionId
 # Query ARG for Storage Accounts with VNet ACLs pointing to Databricks subnets
# update logic for NSP migration
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
    -ResourceGroupName $resourceGroup `
    -Direction Inbound `
    -ServiceTag "AzureDatabricksServerless"
 # Associate all Storage Accounts in transition mode
# foreach ($sa in $storageAccounts) {  
#     Write-Host "Associating $($sa.name) with NSP in transition mode..."  
#     New-AzNetworkSecurityPerimeterAssociation -Name "$($sa.name)-Assoc" -SecurityPerimeterName $nspName -ResourceGroupName $resourceGroup -ProfileId $nspProfile.Id -PrivateLinkResourceId $sa.id -AccessMode 'Learning'  
# } 
