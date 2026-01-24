###
# Todo : use param() to set up command line args for subscriptonId, resourceGroup, nspName, location, profileName
###
# Sign in and set context
Connect-AzAccount
# Set variables
$subscriptionId = "<your subscription id>"
$resourceGroup = "<resource group>"
$nspName    = "databricks-nsp"
$location    = "<region>"
$profileName  = "adb-profile"
 # Select subscription
Select-AzSubscription -SubscriptionId $subscriptionId
 # Query ARG for Storage Accounts with VNet ACLs pointing to Databricks subnets
 


$kql = @"
resources
| where type == "microsoft.storage/storageaccounts"
| where array_length(properties.networkAcls.virtualNetworkRules) > 0
| mvexpand vnr = properties.networkAcls.virtualNetworkRules
| where vnr.id has_any (dynamic(["8453a5d5-9e9e-40c7-87a4-0ab4cc197f48",
"31ef391b-7908-48ec-8c74-e432113b607b",
"6c0d042c-6733-4420-a3cc-4175d0439b29",
"23a8c420-c354-43f9-91f5-59d08c6b3dff",
"9d5fffc7-7640-44a1-ba2b-f77ada7731d4",
"56beece1-dbc8-40ca-8520-e1d514fb2ccc",
"653c13e3-a85b-449b-9d14-e3e9c4b0d391",
"b96a1dc5-559f-4249-a30c-5b5a98023c45",
"b4f59749-ad17-4573-95ef-cc4c63a45bdf",
"d31d7397-093d-4cc4-abd6-28b426c0c882",
"b4f59749-ad17-4573-95ef-cc4c63a45bdf",
"d4a2f931-8db7-49ba-a9ea-18016369fbcb",
"60baf026-ba3d-4d3d-a247-83c4e16439b7",
"41a3b376-d525-4439-bd68-0d601a09e702",
"6e628db8-cfec-4cd9-9b3c-789331b89103",
"c10cf0cd-8008-4327-9402-46aa2337a1c9",
"87ff4ec0-9212-4ce0-880d-1b479c031b8e"]))
| project name, id, resourceGroup, subscriptionId, vnetRuleId = tostring(vnr.id), properties
| summarize by id, name
"@
$storageAccounts = Search-AzGraph -Query $kql -Subscription $subscriptionId
Write-Host "Found $($storageAccounts.Count) Storage Accounts with Databricks VNet ACLs"
if ($storageAccounts.Count -eq 0) {
    Write-Host "No Storage Accounts matched—no NSP work required."
    return
}
# Create Resource Group - comment this next line if using an existing resource group.
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

foreach ($sa in $storageAccounts) {  
    if (Get-AzDenyAssignment -scope $sa.id -ErrorAction SilentlyContinue) {
        Write-Host "Skipping $($sa.name) : identified as workspace default storage (DBFS)."
        continue
    }
    $parts = $sa.id -split '/'
    $resourceGroupName = $parts[4]
    $accountName = $parts[8]
    $nspConfigs = Get-AzStorageNetworkSecurityPerimeterConfiguration -ResourceGroupName $resourceGroupName -AccountName $accountName
    $nspCount = ($nspConfigs | Measure-Object).Count
    if ($nspCount -gt 0) {
        Write-Host "Skipping $($sa.name) : already associated with NSP."
        continue
    }
    Write-Host "Finding $($sa.name) SA resource ID $($sa.id)"
    Write-Host "Associating $($sa.name) with NSP in transition mode..."  
    New-AzNetworkSecurityPerimeterAssociation -Name "$($sa.name)-Assoc" -SecurityPerimeterName $nspName -ResourceGroupName $resourceGroup -ProfileId $nspProfile.Id -PrivateLinkResourceId $sa.id -AccessMode 'Learning'  
}
