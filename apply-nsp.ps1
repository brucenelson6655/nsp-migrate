$subscriptionId = "72d2cdcb-dd88-4ef9-a253-fd33245017d5"
$resourceGroup = "brn-common-wus"
$nspName    = "mig-databricks-nsp"
$location    = "westus"
$profileName  = "adb-profile"
# $storageAccountName = "brnnspglobalcat"
$storageAccountName = "dbstorage7zcyzc6zuilma"
# $storageAccountId = "/subscriptions/72d2cdcb-dd88-4ef9-a253-fd33245017d5/resourceGroups/brn-common-wus/providers/Microsoft.Storage/storageAccounts/brnnspglobalcat"
$storageAccountId = "/subscriptions/72d2cdcb-dd88-4ef9-a253-fd33245017d5/resourceGroups/databricks-rg-brn-common-wus-ws-okktlidzg3s3o/providers/Microsoft.Storage/storageAccounts/dbstorage7zcyzc6zuilma"
# Select subscription
Select-AzSubscription -SubscriptionId $subscriptionId
# Associate all Storage Accounts in transition mode
# foreach ($sa in $storageAccounts) {  
#     Write-Host "Associating $($sa.name) with NSP in transition mode..."  
New-AzNetworkSecurityPerimeterAssociation -Name "$($storageAccountName)-Assoc" -SecurityPerimeterName $nspName -ResourceGroupName $resourceGroup -ProfileId $nspProfile.Id -PrivateLinkResourceId $storageAccountId -AccessMode 'Learning'  
# } 
