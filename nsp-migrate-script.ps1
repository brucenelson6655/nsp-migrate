<#
.PARAMETER Subscription_Id
    The Azure Subscription ID where the NSP will be created.
.PARAMETER Resource_Group
    The name of the Resource Group where the NSP will be created.
.PARAMETER Azure_Region
    The Azure region where the NSP will be created.
.PARAMETER Interactive
    (optional) Boolean flag to indicate whether to run in interactive mode (prompt for each association) or unattended mode.
    Default is $true (interactive mode).
.PARAMETER NSP_Name
    (optional) The name of the Network Security Perimeter to be created. Default is "databricks-nsp".
.PARAMETER NSP_Profile
    (optional) The name of the Network Security Perimeter Profile to be created. Default is "adb-profile".
.PARAMETER Use_Global_Profile
    (optional) Boolean flag to indicate whether to use a single global profile for all associations instead of regional profiles. If set to $true, the script will use the default global profile with service tag "AzureDatabricksServerless" for all associations regardless of location. Default is $false (use regional profiles based on storage account location).    
    This is useful in scenarios where you want to simplify the profile management and are okay with using the global service tag for all locations.
    Currently only in-region access is possible using NSP associations, but in the future Global service endpoint access may be possible which would make this option more relevant.
.PARAMETER Storage_Account_Names
    (optional) An array of Storage Account names to specifically target for association. If not provided, all Storage Accounts with Databricks VNet ACLs will be processed.
.PARAMETER Remove_Serverless_ServiceEndpoints
    (optional) Boolean flag to indicate whether to remove service endpoints from Storage Accounts after associating with NSP in unattended mode.
    Default is $false.  
.PARAMETER Dry_Run_Mode
    (optional) Boolean flag to indicate whether to run the script in dry run mode, which will go through all the motions and log all the actions that would be taken, but will not actually perform any changes to the NSP associations or service endpoint removals. This is useful for testing and validation before running the script for real.
.DESCRIPTION
    This script automates the creation of a Network Security Perimeter (NSP) in Azure
    and associates Storage Accounts with Databricks VNet ACLs to the NSP in learning mode.
    It logs all actions to a timestamped log file in the script's directory. 
.EXAMPLE
    Interactive mode (default):
    ./nsp-migrate-script.ps1 -Subscription_Id "<subscription id>" -Resource_Group "<resource group name>" -Azure_Region "<azure region>"

    Unattended mode:
    ./nsp-migrate-script.ps1 -Subscription_Id "<subscription id>" -Resource_Group "<resource group name>" -Azure_Region "<azure region>" -Interactive False

    Remove Service endpoints in unattended mode 
   ./nsp-migrate-script.ps1 -Subscription_Id "<subscription id>" -Resource_Group "<resource group name>" -Azure_Region "<azure region>" -Interactive False -Remove_Serverless_ServiceEndpoints True

   To Migrate specific a storage account or storeage accounts 
      ./nsp-migrate-script.ps1 -Subscription_Id "<subscription id>" -Resource_Group "<resource group name>" -Azure_Region "<azure region>" -Storage_Account_Names <storage account or comma seperated list of storeage accounts>
.NOTES 
   created by Bruce Nelson Databricks
#>

param( [Parameter(Mandatory)]$Subscription_Id, [Parameter(Mandatory)]$Resource_Group, [Parameter(Mandatory)]$Azure_Region, $NSP_Name="databricks-nsp", $NSP_Profile="adb-profile", $Storage_Account_Names, $Interactive=$true, $Dry_Run_Mode=$false, $Remove_Serverless_ServiceEndpoints=$false, $Use_Global_Profile=$false)

# Set variables
$subscriptionId = $Subscription_Id
$resourceGroup = $Resource_Group
$nspName    = $NSP_Name
$location    = $Azure_Region
$profileName  = $NSP_Profile
# Define the log file path with a unique timestamp (YYYYMMdd_HHmmss format)
$timeStamp = Get-Date -Format yyyyMMdd_HHmmss
$logFileName = "nsp-migrate-log_$timeStamp.log"
$logPath = Join-Path -Path $PSScriptRoot -ChildPath $logFileName
# Start transcription to the unique log file
Start-Transcript -Path $logPath -Append

# interavtive or unattended mode - set to $true to approve each association, false to run unattended
$interactive = $Interactive

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
# Define function to remove service endpoints
function Remove-Serverless-ServiceEndpoints {
param( [Parameter(Mandatory)]$storageAccountName)
# Get the subnet object to retrieve its resource ID
$sekql = @" 
resources
| where type == "microsoft.storage/storageaccounts"
| where name == '$storageAccountName'
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
| project name, id, resourceGroup, subscriptionId, vnetRuleId = tostring(vnr.id), properties
| summarize by id, name, vnetRuleId
"@

    $serviceEndpoints = Search-AzGraph -Query $sekql

    foreach ($storageAccountObject in $serviceEndpoints) {
        $vnetRuleId = $storageAccountObject.vnetRuleId
        $separts = $vnetRuleId -split '/'
        $subnetName = $separts[10]
        $vnetName = $separts[8]
        $vnetRGName = $separts[4]
        Write-Host "Preparing to remove service endpoint for subnet '$subnetName' in VNet '$vnetName' in '$vnetRGName'..."
        $parts = $storageAccountObject.id -split '/'
        $resourceGroupName = $parts[4]
        $storageAccountName = $parts[8]
        Write-Host "Processing subnet rule ID: $vnetRuleId"
        # Remove the virtual network rule from the storage account
        Remove-AzStorageAccountNetworkRule -ResourceGroupName $resourceGroupName -Name $storageAccountName -VirtualNetworkResourceId $vnetRuleId
        Write-Host "Successfully removed the service endpoint for subnet '$subnetName' in VNet '$vnetName' in '$vnetRGName' from storage account '$storageAccountName'."
        
    }
}

if ($interactive -eq $true) {
    Write-Host "Running in interactive mode. You will be prompted for each Storage Account association."
} else {
    Write-Host "Running in unattended mode. All Storage Accounts will be associated without prompts."
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
| project name, id, location, resourceGroup, subscriptionId, properties
| summarize by id, name, location
"@

if ($Storage_Account_Names) {
    Write-Host "Filtering for specified Storage Accounts: $Storage_Account_Names"
    $kql = $ksqlstorageaccounts
} else {
    Write-Host "No specific Storage Accounts provided; querying all Storage Accounts with Databricks VNet ACLs."
}   
# Execute query to get all of the Storage Accounts which have serverless service endpoints configured
$storageAccounts = Search-AzGraph -Query $kql -Subscription $subscriptionId
# if we find nothing (which usually doesn't happen because of DBFS) we can exit early

# Create an empty list of strings
$associateStorageAccount = [System.Collections.Generic.List[object]]::New()
$migrateStorageAccount = [System.Collections.Generic.List[object]]::New()
$associateStorageLocations = [System.Collections.Generic.List[string]]::New()

foreach ($ssa in $storageAccounts) {  
    Write-Host "Evaluating Storage Account: $($ssa.name) in location $($ssa.location)"
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
        Write-Host "Skipping $($ssa.name) : already associated with NSP."
        continue
        # future logic could be added to remove existing NSP association and re-associate with new NSP if needed, but for now we will just skip if any association exists
    }
    # if we have a match add to the list for association with NSP
    $associateStorageAccount.Add($ssa)
    # also add the location to a list to ensure we create NSP profiles for each unique location as needed
    $associateStorageLocations.Add($ssa.location)
}
# let's get the unique list of locations for the storage accounts we need to associate so we can create NSP profiles for each location as needed, this is because service tags are location specific and we need to ensure we have a profile with the correct service tag for each location
$uniqueLocations = $associateStorageLocations | Select-Object -Unique
# This isn't needed not becuase we have a function for this .. $allLocations = @("AustraliaCentral","AustraliaCentral2","AustraliaEast","AustraliaSoutheast","AustriaEast","BelgiumCentral","BrazilSouth","BrazilSoutheast","CanadaCentral","CanadaEast","CentralIndia","CentralUS","CentralUSEUAP","ChileCentral","DenmarkEast","EastAsia","EastUS","EastUS2","EastUS2EUAP","EastUS3","FranceCentral","FranceSouth","GermanyNorth","GermanyWestCentral","IndiaSouthCentral","IndonesiaCentral","IsraelCentral","IsraelNorthwest","ItalyNorth","JapanEast","JapanWest","JioIndiaCentral","JioIndiaWest","KoreaCentral","KoreaSouth","MalaysiaSouth","MalaysiaWest","MexicoCentral","NewZealandNorth","NorthCentralUS","NortheastUS5","NorthEurope","NorwayEast","NorwayWest","PolandCentral","QatarCentral","SaudiArabiaEast","SouthAfricaNorth","SouthAfricaWest","SouthCentralUS","SouthCentralUS2","SoutheastAsia","SoutheastAsia3","SoutheastUS","SoutheastUS3","SoutheastUS5","SouthIndia","SouthwestUS","SpainCentral","SwedenCentral","SwedenSouth","SwitzerlandNorth","SwitzerlandWest","TaiwanNorth","TaiwanNorthwest","UAECentral","UAENorth","UKSouth","UKWest","WestCentralUS","WestCentralUSFRE","WestEurope","WestIndia","WestUS", "WestUS2", "WestUS3")



Write-Host "Found $($associateStorageAccount.Count) Storage Accounts with Databricks VNet ACLs and/or not yet associated with NSP."
if ($associateStorageAccount.Count -eq 0) {
    Write-Host "No Storage Accounts matched, no NSP work required."
    return
} else {
    # write report of targeted storage accounts
    Write-Host "The following Storage Accounts were identified for migration:"
    foreach ($sa in $associateStorageAccount) {
        $parts = $sa.id -split '/'
        $resourceGroupName = $parts[4]
        Write-Host "- $($sa.name) Resource Group: $resourceGroupName Location: $($sa.location)"
    }

    if ($interactive -eq $true) {
        $userInput = GetUserInput -promptMessage "Continue Migrating Storage Accounts ? [Y/N, default: Y]" -defaultValue 'Y'
        if ($userInput -eq 'Y') {
           Write-Host "Continuing..."
        } else {
            
            Write-Host "Exiting as per user input."
            return
        }   
    } else {
        Write-Host "Continuing in unattended mode..."
    }   
}
# lets create or verify NSP and profiles before we start associating storage accounts, this way we can ensure everything is in place before we start making changes to the storage accounts, and also avoid any issues with creating profiles in the middle of the association process which could cause delays if we have a lot of storage accounts to process
# Create Resource Group - if it doesn't already exist, if it does exist we will just use the existing resource group for the NSP
if ($Dry_Run_Mode -eq $true) {
    Write-Host "Dry run mode is enabled, skipping actual creation of resource group, NSP, and profiles. This is for testing and validation purposes only."
} else {    
if (-not (Get-AzResourceGroup -Name $resourceGroup -ErrorAction SilentlyContinue)) {
    Write-Host "Resource group '$resourceGroup' doesnot exist. Creating..."
    # Create the resource group
    New-AzResourceGroup -Name $resourceGroup -Location $location
    Write-Host "Resource group '$resourceGroup' created successfully in '$location'."
} else {
    Write-Host "Resource group '$resourceGroup' already exists."
}
# Create NSP and Profiles if they don't already exist, if they do exist we will just use the existing NSP and profiles for the associations
if (-not (Get-AzNetworkSecurityPerimeter -Name $nspName -ResourceGroupName $resourceGroup -ErrorAction SilentlyContinue)) {
    write-Host "Creating Network Security Perimeter '$nspName' in resource group '$resourceGroup'..."
    New-AzNetworkSecurityPerimeter -Name $nspName -ResourceGroupName $resourceGroup -Location $location
    Write-Host "Created Network Security Perimeter '$nspName' in resource group '$resourceGroup'." 
} else {
   Write-Host "Network Security Perimeter '$nspName' already exists in resource group '$resourceGroup'."Group -SecurityPerimeterName $nspName
} 
# verify or Create Profile plus a default profile for rougue location names or future feature of user choice. 
#create default profile with default service tag to ensure we have a profile to associate with if we encounter any location names that don't match the service tag format, this way we can avoid any issues with associating storage accounts that have location names that don't match the service tag format which could cause connectivity issues for the storage accounts once associated with the NSP
$loc = "global"
if (-not (Get-AzNetworkSecurityPerimeterProfile -Name "$profileName-$loc" -ResourceGroupName $resourceGroup -SecurityPerimeterName $nspName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating Network Security Perimeter Profile '$profileName-$loc' for location '$loc'..."
    $defaultNspProfile = New-AzNetworkSecurityPerimeterProfile -Name "$profileName-$loc" -SecurityPerimeterName $nspName -ResourceGroupName $resourceGroup
        # Create Rule to approve AzureDatabricksServerless
    New-AzNetworkSecurityPerimeterAccessRule -Name "Allow-AzureDatabricks-Serverless" `
        -ProfileName $defaultNspProfile.Name `
        -SecurityPerimeterName $nspName `
        -ResourceGroupName $resourceGroup `
        -Direction Inbound `
        -ServiceTag "AzureDatabricksServerless"
} else {
        Write-Host "Network Security Perimeter Profile '$profileName-$loc' already exists for location '$loc'."
}
# create regional profiles based on the unique list of locations we have from the storage accounts we need to associate, this way we ensure we have the correct service tags for each location which is required for the NSP profiles, and avoid any issues with incorrect service tags which could cause connectivity issues for the storage accounts once associated with the NSP
foreach ($uniqiueLoc  in $uniqueLocations) {
    $loc = Convert-LocationToServiceTagFormat -location $uniqiueLoc
    Write-Host "Processing NSP Profile for location '$loc'..."

    if (-not (Get-AzNetworkSecurityPerimeterProfile -Name "$profileName-$loc" -ResourceGroupName $resourceGroup -SecurityPerimeterName $nspName -ErrorAction SilentlyContinue)) {
        Write-Host "Creating Network Security Perimeter Profile '$profileName-$loc' for location '$loc'..."
        $nspProfile = New-AzNetworkSecurityPerimeterProfile -Name "$profileName-$loc" -SecurityPerimeterName $nspName -ResourceGroupName $resourceGroup
        # Create Rule to approve AzureDatabricksServerless
        New-AzNetworkSecurityPerimeterAccessRule -Name "Allow-AzureDatabricks-Serverless-$loc" `
            -ProfileName $nspProfile.Name `
            -SecurityPerimeterName $nspName `
            -ResourceGroupName $resourceGroup `
            -Direction Inbound `
            -ServiceTag "AzureDatabricksServerless.$loc"
    } else {
        Write-Host "Network Security Perimeter Profile '$profileName-$loc' already exists for location '$loc'."
    } 
}
Write-Host "NSP and Profiles are ready, starting association of Storage Accounts with NSP..."
}
Write-Host -ForegroundColor Red "`n`nUsing NSP '$nspName' in resource group '$resourceGroup' for associations.`n"

# Associate Storage Accounts with NSP

foreach ($sa in $associateStorageAccount) {  
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
    Write-Host -ForegroundColor DarkYellow "Finding $($accountName) SA resource ID $($sa.id) SA location $($sa.location)"
    # convert location to match service tag format for profile lookup, this is needed because some location names don't match the service tag format which would cause issues with profile lookup and association if we don't convert the location name to match the service tag format, this way we can ensure we have the correct profile for each storage account based on its location which is required for the NSP association and connectivity
    $loc = Convert-LocationToServiceTagFormat -location $sa.location
    $nspProfile = Get-AzNetworkSecurityPerimeterProfile -Name "$profileName-$loc" -ResourceGroupName $resourceGroup -SecurityPerimeterName $nspName -ErrorAction SilentlyContinue
    $sa | Add-Member -MemberType NoteProperty -Name "nspName" -Value $nspName -Force
    $sa | Add-Member -MemberType NoteProperty -Name "nspLocation" -Value $sa.location -Force
    $sa | Add-Member -MemberType NoteProperty -Name "nspResourceGroup" -Value $resourceGroup -Force
    $sa | Add-Member -MemberType NoteProperty -Name "nspProfile" -Value $nspProfile.Name -Force
    $sa | Add-Member -MemberType NoteProperty -Name "nspServiceTag" -Value "AzureDatabricksServerless.$loc" -Force  
    $sa | Add-Member -MemberType NoteProperty -Name "nspProfileId" -Value $nspProfile.Id -Force
    $sa | Add-Member -MemberType NoteProperty -Name "stLocation" -Value $loc -Force
    $sa | Add-Member -MemberType NoteProperty -Name "resourceGroup" -Value $resourceGroupName -Force
    $sa | Add-Member -MemberType NoteProperty -Name "deleteServiceEndpoints" -Value $Remove_Serverless_ServiceEndpoints -Force
    if ($interactive -eq $true) {
        # $userInput = GetUserInput -promptMessage "Associate $($sa.name) with NSP $($nspName) using Profile $($nspProfile.Name) ? [Y/N, default: Y]" -defaultValue 'Y'
        if ($Use_Global_Profile -eq $true) {
            $useRegionalProfileInput = GetUserInput -promptMessage "For storage account $($sa.name), use regional profile for location '$loc' which has service tag 'AzureDatabricksServerless.$loc' or default global profile with service tag 'AzureDatabricksServerless' ? [R]egional / [G]lobal, default: R]" -defaultValue 'R'
            if ($useRegionalProfileInput -eq 'G') {
                $loc = "global"
                $nspProfile = Get-AzNetworkSecurityPerimeterProfile -Name "$profileName-$loc" -ResourceGroupName $resourceGroup -SecurityPerimeterName $nspName -ErrorAction SilentlyContinue
                $sa.nspProfile = $nspProfile.Name
                $sa.nspServiceTag = "AzureDatabricksServerless"
                $sa.nspProfileId = $nspProfile.Id
                $sa.stLocation = $loc
                Write-Host "User has chosen to use global profile for association."
            } else {
                Write-Host "User has chosen to use regional profile for association."
            }
        }
        $userInput = GetUserInput -promptMessage "Associate $($sa.name) with NSP $($nspName) using Profile $($nspProfile.Name) ? [Y/N, default: Y]" -defaultValue 'Y'
        if ($userInput -eq 'Y') {
           Write-Host "Associating $($accountName) with NSP $($nspName) using Profile $($nspProfile.Name) in transition mode..."  
           Write-Host -ForegroundColor Green "Association details for $($sa.name): NSP: $($sa.nspName) Profile: $($sa.nspProfile) Location: $($sa.stLocation) Resource Group: $($sa.resourceGroup)"
           # New-AzNetworkSecurityPerimeterAssociation -Name "$($accountName)-Assoc" -SecurityPerimeterName $nspName -ResourceGroupName $resourceGroup -ProfileId $nspProfile.Id -PrivateLinkResourceId $sa.id -AccessMode 'Learning' 
           $SEuserInput = GetUserInput -promptMessage "Remove Serverless Service Endpoints from $($sa.name) with NSP $($nspName) ? [Y/N, default: N]" -defaultValue 'N'
           if ($SEuserInput -eq 'Y') {
               # Remove-Serverless-ServiceEndpoints -storageAccountName $sa.name
               $sa.deleteServiceEndpoints = $true
               Write-Host "Service endpoints will be removed for $($sa.name) as per user input."
           } else {
               $sa.deleteServiceEndpoints = $false
               Write-Host "Skipping service endpoint removal for $($sa.name) as per user input."
           }
           ## Load the $sa object into a new list that we will process after the loop to do the actual associations and service endpoint removals, this way we can avoid any issues with modifying the storage account object while we are still looping through it which could cause issues with the loop and also allows us to batch the associations and service endpoint removals after we have all the user input collected for each storage account, this way we can also provide a summary of all the associations and service endpoint removals that will be performed before we actually perform them, giving the user one last chance to review and confirm before we make any changes to the storage accounts
           $migrateStorageAccount.Add($sa)
        } else {
            Write-Host "Skipping $($sa.name) as per user input."
        }
    } else {
        Write-Host "Associating $($sa.name) with NSP $($nspName) in transition mode..."  
        $migrateStorageAccount.Add($sa)

        ## Load the $sa object into a new list that we will process after the loop to do the actual associations and service endpoint removals, this way we can avoid any issues with modifying the storage account object while we are still looping through it which could cause issues with the loop and also allows us to batch the associations and service endpoint removals after we have all the user input collected for each storage account, this way we can also provide a summary of all the associations and service endpoint removals that will be performed before we actually perform them, giving the user one last chance to review and confirm before we make any changes to the storage accounts
        # New-AzNetworkSecurityPerimeterAssociation -Name "$($sa.name)-Assoc" -SecurityPerimeterName $nspName -ResourceGroupName $resourceGroup -ProfileId $nspProfile.Id -PrivateLinkResourceId $sa.id -AccessMode 'Learning'  
        # if ($Remove_Serverless_ServiceEndpoints -eq $true) {
        #     Remove-Serverless-ServiceEndpoints -storageAccountName $sa.name
        # }
    }
}
## we will process the associations and service endpoint removals after we have collected all the user input for each storage account, this way we can provide a summary of all the associations and service endpoint removals that will be performed before we actually perform them, giving the user one last chance to review and confirm before we make any changes to the storage accounts
Write-Host "`nSummary of Associations and Service Endpoint Removals to be performed:"
foreach ($sa in $migrateStorageAccount) {
    Write-Host -ForegroundColor Green "`nStorage Account: $($sa.name) `nNSP: $($sa.nspName) Profile: $($sa.nspProfile) Location: $($sa.stLocation) Resource Group: $($sa.resourceGroup) `nRemove Service Endpoints: $($sa.deleteServiceEndpoints)"
    if ($Dry_Run_Mode -eq $true) {
        Write-Host "Dry run mode is enabled, skipping actual association and service endpoint removal for $($sa.name)."
    } else {
        # Perform the actual association
        New-AzNetworkSecurityPerimeterAssociation -Name "$($sa.name)-Assoc" -SecurityPerimeterName $sa.nspName -ResourceGroupName $sa.nspResourceGroup -ProfileId $sa.nspProfileId -PrivateLinkResourceId $sa.id -AccessMode 'Learning'  
        Write-Host "Associated $($sa.name) with NSP $($sa.nspName) using Profile $($sa.nspProfile) in transition mode."
        if ($sa.deleteServiceEndpoints -eq $true) {
            Remove-Serverless-ServiceEndpoints -storageAccountName $sa.name
            Write-Host "Removed service endpoints for $($sa.name) as per user input."
        } else {
            Write-Host "Skipping service endpoint removal for $($sa.name) as per user input."
        }
    }   
}
    


#stop logging
Stop-Transcript
