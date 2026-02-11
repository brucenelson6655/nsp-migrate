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
.PARAMETER Storage_Account_Names
    (optional) An array of Storage Account names to specifically target for association. If not provided, all Storage Accounts with Databricks VNet ACLs will be processed.
.PARAMETER Remove_Serverless_ServiceEndpoints
    (optional) Boolean flag to indicate whether to remove service endpoints from Storage Accounts after associating with NSP in unattended mode.
    Default is $false.  
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

param( [Parameter(Mandatory)]$Subscription_Id, [Parameter(Mandatory)]$Resource_Group, [Parameter(Mandatory)]$Azure_Region, $NSP_Name="databricks-nsp", $NSP_Profile="adb-profile", $Storage_Account_Names, $Interactive=$true, $Remove_Serverless_ServiceEndpoints=$false)

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
| project name, id, resourceGroup, subscriptionId, vnetRuleId = tostring(vnr.id), properties
| summarize by id, name
"@

$ksqlstorageaccounts = @"
resources
| where type == "microsoft.storage/storageaccounts"
| where name in ('$($Storage_Account_Names -join "','")')
| project name, id, resourceGroup, subscriptionId, properties
| summarize by id, name
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

foreach ($ssa in $storageAccounts) {  
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
    }

    $associateStorageAccount.Add($ssa)
}

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
        Write-Host "- $($sa.name) Resource Group: $resourceGroupName"
    }

    if ($interactive -eq $true) {
        $defaultValue = 'N'
        $promptMessage = "Continue Migrating Storage Accounts ? [Y/N, default: $defaultValue]"
        $response = Read-Host -Prompt $promptMessage

        # If the response is empty, use the default value. Otherwise, use the response.
        $userInput = if ([string]::IsNullOrEmpty($response)) { $defaultValue } else { $response }

        # Process the input (case-insensitive comparison)
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
# Create Resource Group - comment this next line if using an existing resource group.
###
# todo redo if not exstis logic 
if (-not (Get-AzResourceGroup -Name $resourceGroup -ErrorAction SilentlyContinue)) {
    Write-Host "Resource group '$resourceGroup' doesnot exist. Creating..."
    
    # Create the resource group
    New-AzResourceGroup -Name $resourceGroup -Location $location
    
    Write-Host "Resource group '$resourceGroup' created successfully in '$location'."
} else {
    Write-Host "Resource group '$resourceGroup' already exists."
}
# Create NSP
###
# Todo add if not exists logic is needed for NSP, profile and rule
if (-not (Get-AzNetworkSecurityPerimeter -Name $nspName -ResourceGroupName $resourceGroup -ErrorAction SilentlyContinue)) {
    write-Host "Creating Network Security Perimeter '$nspName' in resource group '$resourceGroup'..."
    # Create NSP
    New-AzNetworkSecurityPerimeter -Name $nspName -ResourceGroupName $resourceGroup -Location $location
    Write-Host "Created Network Security Perimeter '$nspName' in resource group '$resourceGroup'." 
    # Create Profile
    $nspProfile = New-AzNetworkSecurityPerimeterProfile -Name $profileName -SecurityPerimeterName $nspName -ResourceGroupName $resourceGroup
    # Create Rule to approve AzureDatabricksServerless
    New-AzNetworkSecurityPerimeterAccessRule -Name "Allow-AzureDatabricks-Serverless" `
        -ProfileName $nspProfile.Name `
        -SecurityPerimeterName $nspName `
        -ResourceGroupName $resourceGroup `
        -Direction Inbound `
        -ServiceTag "AzureDatabricksServerless"
} else {
   Write-Host "Network Security Perimeter '$nspName' already exists in resource group '$resourceGroup'."  
   $nspProfile = Get-AzNetworkSecurityPerimeterProfile -Name $profileName -ResourceGroupName $resourceGroup -SecurityPerimeterName $nspName
} 

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
    Write-Host "Finding $($sa.name) SA resource ID $($sa.id)"
    if ($interactive -eq $true) {
        $defaultValue = 'Y'
        $promptMessage = "Associate $($sa.name) with NSP $($nspName) ? [Y/N, default: $defaultValue]"
        $response = Read-Host -Prompt $promptMessage

        # If the response is empty, use the default value. Otherwise, use the response.
        $userInput = if ([string]::IsNullOrEmpty($response)) { $defaultValue } else { $response }

        # Process the input (case-insensitive comparison)
        if ($userInput -eq 'Y') {
           Write-Host "Associating $($sa.name) with NSP $($nspName) in transition mode..."  
           New-AzNetworkSecurityPerimeterAssociation -Name "$($sa.name)-Assoc" -SecurityPerimeterName $nspName -ResourceGroupName $resourceGroup -ProfileId $nspProfile.Id -PrivateLinkResourceId $sa.id -AccessMode 'Learning' 
           $SEdefaultValue = 'N'
           $SEpromptMessage = "Remove Serverless Service Endpoints from $($sa.name) with NSP $($nspName) ? [Y/N, default: $SEdefaultValue]"
           $SEresponse = Read-Host -Prompt $SEpromptMessage

        If the response is empty, use the default value. Otherwise, use the response.
          $SEuserInput = if ([string]::IsNullOrEmpty($SEresponse)) { $SEdefaultValue } else { $SEresponse }
           if ($SEuserInput -eq 'Y') {
               Remove-Serverless-ServiceEndpoints -storageAccountName $sa.name
           } else {
               Write-Host "Skipping service endpoint removal for $($sa.name) as per user input."
           }
        } else {
            Write-Host "Skipping $($sa.name) as per user input."
        }
    } else {
        Write-Host "Associating $($sa.name) with NSP $($nspName) in transition mode..."  
        New-AzNetworkSecurityPerimeterAssociation -Name "$($sa.name)-Assoc" -SecurityPerimeterName $nspName -ResourceGroupName $resourceGroup -ProfileId $nspProfile.Id -PrivateLinkResourceId $sa.id -AccessMode 'Learning'  
        if ($Remove_Serverless_ServiceEndpoints -eq $true) {
            Remove-Serverless-ServiceEndpoints -storageAccountName $sa.name
        }
    }
}


#stop logging
Stop-Transcript
