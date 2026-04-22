<#
.PARAMETER Subscription_Id
    The Azure Subscription ID where the NSP will be created.
.PARAMETER Storage_Account_Names
    (optional) An array of Storage Account names to specifically target for association. If not provided, all Storage Accounts with Databricks VNet ACLs will be processed.
.DESCRIPTION
    This script checks for Storage Accounts with Databricks VNet ACLs that need to be
    migrated to a Network Security Perimeter (NSP). It queries Azure Resource Graph to
    identify eligible Storage Accounts and generates a report for migration planning.
    All actions are logged to a timestamped log file in the script's directory.
.EXAMPLE
    Interactive mode (default):
    ./nsp-check.ps1 -Subscription_Id "12345678-1234-1234-1234-123456789012"

    To target specific Storage Accounts:
    ./nsp-check.ps1 -Subscription_Id "12345678-1234-1234-1234-123456789012" -Storage_Account_Names "storageaccount1","storageaccount2"
.NOTES 
   created by Bruce Nelson Databricks
#>

param( [Parameter(Mandatory)]$Subscription_Id, $Storage_Account_Names)

# Set variables
$subscriptionId = $Subscription_Id

# Define the log file path with a unique timestamp (YYYYMMdd_HHmmss format)
$timeStamp = Get-Date -Format yyyyMMdd_HHmmss
$logFileName = "nsp-migrate-log_$timeStamp.log"
$logPath = Join-Path -Path $PSScriptRoot -ChildPath $logFileName
# Start transcription to the unique log file
Start-Transcript -Path $logPath -Append

# Define function to convert location name to match service tag format
function Convert-LocationToServiceTagFormat {
    param( [Parameter(Mandatory)]$location)
    $tagLocation = "global"
    $allLocations = @("AustraliaCentral","AustraliaCentral2","AustraliaEast","AustraliaSoutheast","AustriaEast","BelgiumCentral","BrazilSouth","BrazilSoutheast","CanadaCentral","CanadaEast","CentralIndia","CentralUS","CentralUSEUAP","ChileCentral","DenmarkEast","EastAsia","EastUS","EastUS2","EastUS2EUAP","EastUS3","FranceCentral","FranceSouth","GermanyNorth","GermanyWestCentral","IndiaSouthCentral","IndonesiaCentral","IsraelCentral","IsraelNorthwest","ItalyNorth","JapanEast","JapanWest","JioIndiaCentral","JioIndiaWest","KoreaCentral","KoreaSouth","MalaysiaSouth","MalaysiaWest","MexicoCentral","NewZealandNorth","NorthCentralUS","NortheastUS5","NorthEurope","NorwayEast","NorwayWest","PolandCentral","QatarCentral","SaudiArabiaEast","SouthAfricaNorth","SouthAfricaWest","SouthCentralUS","SouthCentralUS2","SoutheastAsia","SoutheastAsia3","SoutheastUS","SoutheastUS3","SoutheastUS5","SouthIndia","SouthwestUS","SpainCentral","SwedenCentral","SwedenSouth","SwitzerlandNorth","SwitzerlandWest","TaiwanNorth","TaiwanNorthwest","UAECentral","UAENorth","UKSouth","UKWest","WestCentralUS","WestCentralUSFRE","WestEurope","WestIndia","WestUS", "WestUS2", "WestUS3")
    foreach ($ccloc in $allLocations) { 
        if ($location -match $ccloc) {
            $tagLocation  = $ccloc
        } 
    }
    return $tagLocation
}
# Define function to get user input with default value
function GetUserInput {
    param( [Parameter(Mandatory)]$promptMessage, [string]$defaultValue = 'Y')
    $response = Read-Host -Prompt $promptMessage
    $userInput = if ([string]::IsNullOrEmpty($response)) { $defaultValue } else { $response }
    return $userInput
}

# Define a function to check for private endpoint connections
function Check-PrivateEndpointConnections {
    param( [Parameter(Mandatory)]$storageAccountName)
    $pecsql = @"
resources
| where type == "microsoft.storage/storageaccounts"
| where name == '$storageAccountName'
| where array_length(properties.privateEndpointConnections) > 0
| mv-expand connections = properties.privateEndpointConnections
| project 
    StorageAccountName = name, 
    ResourceGroup = resourceGroup, 
    PrivateEndpointId = connections.properties.privateEndpoint.id,
    Status = connections.properties.privateLinkServiceConnectionState.status,
    GroupId = connections.properties.groupId
"@

    $privateEndpoints = Search-AzGraph -Query $pecsql
    if ($privateEndpoints -and $privateEndpoints.Count -gt 0) {    
        return $true
    } else {
        return $false
    }
}

# Define the log file path with a unique timestamp (YYYYMMdd_HHmmss format)
$timeStamp = Get-Date -Format yyyyMMdd_HHmmss
$logFileName = "nsp-migrate-log_$timeStamp.log"
$logPath = Join-Path -Path $PSScriptRoot -ChildPath $logFileName

# Sign in and set context
Connect-AzAccount -Subscription $subscriptionId
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
"d4a2f931-8db7-49ba-a9ea-18016369fbcb",
"60baf026-ba3d-4d3d-a247-83c4e16439b7",
"41a3b376-d525-4439-bd68-0d601a09e702",
"6e628db8-cfec-4cd9-9b3c-789331b89103",
"c10cf0cd-8008-4327-9402-46aa2337a1c9",
"87ff4ec0-9212-4ce0-880d-1b479c031b8e"]))
| project name, id, location, resourceGroup, subscriptionId, vnetRuleId = tostring(vnr.id), properties
| summarize by id, name, location
"@

$ksqlstorageaccounts = @"
resources
| where type == "microsoft.storage/storageaccounts"
| where name in ('$($Storage_Account_Names -join "','")')
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
"d4a2f931-8db7-49ba-a9ea-18016369fbcb",
"60baf026-ba3d-4d3d-a247-83c4e16439b7",
"41a3b376-d525-4439-bd68-0d601a09e702",
"6e628db8-cfec-4cd9-9b3c-789331b89103",
"c10cf0cd-8008-4327-9402-46aa2337a1c9",
"87ff4ec0-9212-4ce0-880d-1b479c031b8e"]))
| project name, id, location, resourceGroup, subscriptionId, properties
| summarize by id, name, location
"@

if ($Storage_Account_Names) {
    Write-Host -ForegroundColor Green "Filtering for specified Storage Accounts: $Storage_Account_Names"
    $kql = $ksqlstorageaccounts
} else {
    Write-Host -ForegroundColor Green "No specific Storage Accounts provided; querying all Storage Accounts with Databricks VNet ACLs."
}   
# Execute query to get all of the Storage Accounts which have serverless service endpoints configured
$storageAccounts = Search-AzGraph -Query $kql -Subscription $subscriptionId
# if we find nothing (which usually doesn't happen because of DBFS) we can exit early

# Create an empty list of strings
$associateStorageAccount = [System.Collections.Generic.List[object]]::New()
$associateStorageLocations = [System.Collections.Generic.List[string]]::New()

foreach ($ssa in $storageAccounts) {  
    Write-Host -ForegroundColor Green "Evaluating Storage Account: $($ssa.name) in location $($ssa.location)"
    if (Get-AzDenyAssignment -scope $ssa.id -ErrorAction SilentlyContinue) {
        Write-Host "Skipping $($ssa.name) : identified as workspace default storage (DBFS)."
        continue
    }
    $parts = $ssa.id -split '/'
    $resourceGroupName = $parts[4]
    $accountName = $parts[8]
    $nspConfigs = Get-AzStorageNetworkSecurityPerimeterConfiguration -ResourceGroupName $resourceGroupName -AccountName $accountName
    $nspCount = ($nspConfigs | Measure-Object).Count
    if ($nspCount -gt 0) {
        Write-Host -ForegroundColor Red "Skipping $($ssa.name) : already associated with NSP."
        continue
        # future logic could be added to remove existing NSP association and re-associate with new NSP if needed, but for now we will just skip if any association exists
    }
    # if we have a match add to the list for association with NSP
    $associateStorageAccount.Add($ssa)
    # also add the location to a list to ensure we create NSP profiles for each unique location as needed
    $associateStorageLocations.Add($ssa.location)
}

Write-Host "`nFound $($associateStorageAccount.Count) Storage Accounts with Databricks VNet ACLs and not yet associated with NSP."
if ($associateStorageAccount.Count -eq 0) {
    Write-Host "No Storage Accounts matched, no NSP work required."
    return
} else {
    # write report of targeted storage accounts
    Write-Host "The following Storage Accounts were identified for migration:"
    foreach ($sa in $associateStorageAccount) {
        $parts = $sa.id -split '/'
        $resourceGroupName = $parts[4]
        Write-Host -ForegroundColor DarkCyan "`n- $($sa.name) Resource Group: $resourceGroupName Location: $($sa.location)"
            # check for private endpoint connections and warn if found
        if (Check-PrivateEndpointConnections -storageAccountName $sa.name) {
            Write-Host -ForegroundColor Yellow "Warning: Storage Account '$($sa.name)' has private endpoint connections. Manual review of private endpoints and the resource firewall for this storage account is strongly recommended."
        }
    }

}

Write-Host -ForegroundColor Green "`nCompleted evaluation of Storage Accounts for NSP association.`n"
  


#stop logging
Stop-Transcript
