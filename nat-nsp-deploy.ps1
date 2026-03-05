<#
.SYNOPSIS
    This script retrieves Databricks NAT IP ranges and creates/updates Azure Network Security Perimeter (NSP) access profiles for specified regions.        
.DESCRIPTION
    The script performs the following steps:
    1. Fetches Databricks IP ranges from the official endpoint.
    2. Filters for Azure inbound NAT IPs.
    3. Groups IPs by region.    
    4. Optionally filters for specific regions.
    5. Verifies Azure authentication and sets subscription context.
    6. Retrieves the specified NSP.
    7. Creates or updates NSP access profiles with the relevant CIDR blocks for each region.
.PARAMETER Subscription_Id
    The Azure subscription ID where the NSP is located.
.PARAMETER Resource_Group
    The name of the resource group containing the NSP.
.PARAMETER NSP_Name
    The name of the Network Security Perimeter to which profiles will be added.
.PARAMETER Regions
    An optional array of regions to filter the IPs. Use "*" for all regions or specify specific regions like @("eastus", "westus").
.PARAMETER NSP_ProfileNamePrefix
    An optional prefix for the NSP access profile names. Default is "databricks-nat".
.PARAMETER NSP_Profile
    An optional parameter to specify a single NSP profile name to which all IPs will be added. If set, the Regions parameter will be ignored and all IPs will be added to this single profile.
.EXAMPLE
    .\nat-nsp-deploy.ps1 -Subscription_Id "your-subscription-id"
    -Resource_Group "your-resource-group"
    -NSP_Name "your-nsp-name"
    This example will deploy NSP access profiles for all regions with the default profile name prefix.
.EXAMPLE
    .\nat-nsp-deploy.ps1 -Subscription_Id "your-subscription-id"
    -Resource_Group "your-resource-group"
    -NSP_Name "your-nsp-name"
    -Regions @("eastus", "westus")
    This example will deploy NSP access profiles only for the eastus and westus regions.
.NOTES
    - Ensure you have the necessary permissions to create/update NSP profiles in the specified subscription and resource group.
    - The script uses the Az PowerShell module, so make sure it is installed and
        you are authenticated to Azure before running the script.               
    - The actual method to add rules to a profile may vary based on the Azure SDK version. Adjust the code accordingly if needed.   
    - Always test the script in a non-production environment before deploying to production.
    - For any issues or questions, refer to the Azure documentation or contact support.
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
    [Parameter(Mandatory=$true)]
    [string]$Subscription_Id,

    [Parameter(Mandatory=$true)]
    [string]$Resource_Group,

    [Parameter(Mandatory=$true)]
    [string]$NSP_Name,

    [Parameter(Mandatory=$false)]
    [string[]]$Regions = @("*"),  # "*" for all regions, or specify specific regions like @("eastus", "westus")

    [Parameter(Mandatory=$false)]
    [string]$NSP_ProfileNamePrefix = "databricks-nat", # Prefix for regional NSP profile names, e.g., "databricks-nat-eastus"

    [Parameter(Mandatory=$false)]
    [string]$NSP_Profile # For Single profile with all IPs, specify a name here. If set, Regions parameter will be ignored and all IPs will be added to this single profile.
)

# enforce strict mode for better linting
Set-StrictMode -Version Latest

# Set error action preference
$ErrorActionPreference = "Stop"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARNING","ERROR","SUCCESS")] [string]$Level = "default"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Level) {
        "INFO"    { Write-Verbose "[$timestamp] $Message" }
        "WARNING" { Write-Warning "[$timestamp] $Message" }
        "ERROR"   { Write-Error "[$timestamp] $Message" }
        "SUCCESS" { Write-Host -ForegroundColor Green "[$timestamp] [SUCCESS] $Message" }
        default    { Write-Host -ForegroundColor DarkCyan "[$timestamp] [$Level] $Message" }
    }
}

try {
    Write-Log "Starting Databricks NAT IP collection and NSP profile creation..."
    
    # Step 1: Fetch Databricks IP ranges
    Write-Log "Fetching Databricks IP ranges from https://www.databricks.com/networking/v1/ip-ranges.json"
    $response = Invoke-RestMethod -Uri "https://www.databricks.com/networking/v1/ip-ranges.json" -Method Get
    Write-Log "Successfully retrieved IP ranges. Total CIDR blocks: $($response.prefixes.ipv4Prefixes.Count)"
    
    

    # Step 2: Filter for Azure inbound NAT trafficƒ
    Write-Log "Filtering for Azure inbound NAT traffic..."
    $azureNatIps = $response.prefixes | Where-Object {
        $_.platform -eq "azure" -and $_.type -eq "outbound"
    }
    
    if (-not $azureNatIps.ipv4Prefixes -or $azureNatIps.ipv4Prefixes.Count -eq 0) {
        Write-Log "No Azure outbound NAT IPs found!" "WARNING"
        exit 0
    }
    
    Write-Log "Found $($azureNatIps.ipv4Prefixes.Count) Azure outbound NAT IPs"
    
    # Step 3: Group by region
    $ipsByRegion = $azureNatIps | Group-Object -Property region
    
    Write-Log "IPs grouped by region: $($ipsByRegion.Count) regions"
    
    # Step 4: Filter regions if specified
    if ($Regions[0] -ne "*") {
        $ipsByRegion = $ipsByRegion | Where-Object { $_.Name -in $Regions }
        Write-Log "Filtered to $($ipsByRegion.Count) requested regions: $($Regions -join ', ')"
    }


    # Step 5: Ensure logged in to Azure
    Write-Log "Verifying Azure authentication..."
    $currentContext = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $currentContext) {
        Write-Log "Not authenticated to Azure. Running Connect-AzAccount..." "WARNING"
        # Sign in and set context
        Connect-AzAccount -Subscription $Subscription_Id
    }
    # Select subscription
    Select-AzSubscription -SubscriptionId $Subscription_Id
    # Set subscription context
    Set-AzContext -SubscriptionId $Subscription_Id | Out-Null
    Write-Log "Set subscription context to: $Subscription_Id"
    
    # Step 6: Get or verify NSP exists
    Write-Log "Retrieving Network Security Perimeter: $NSP_Name in resource group: $Resource_Group"
    $nsp = Get-AzNetworkSecurityPerimeter -ResourceGroupName $Resource_Group -Name $NSP_Name -ErrorAction SilentlyContinue
    
    if (-not $nsp) {
        Write-Log "Network Security Perimeter '$NSP_Name' not found in resource group '$Resource_Group'" "ERROR"
        exit 1
    }
    
    Write-Log "Found NSP: $($nsp.Id)"
    
    # Step 7: Create or update profiles with regional IPs
    Write-Log "Creating/updating NSP profiles with regional NAT IPs..."
    
    foreach ($regionGroup in $ipsByRegion) {
        $region = $regionGroup.Name
        if ($NSP_Profile) {
            $profileName = $NSP_Profile
        } else {
            $profileName = "${NSP_ProfileNamePrefix}-$region"
        }
        $cidrs = $regionGroup.Group.ipv4Prefixes
        
        Write-Log "Processing region '$region' with $($cidrs.Count) CIDR blocks..."
        
        # Get or create profile
        $nspprofile = Get-AzNetworkSecurityPerimeterProfile -ResourceGroupName $Resource_Group `
            -SecurityPerimeterName $NSP_Name -Name $profileName -ErrorAction SilentlyContinue
        
        if (-not $nspprofile) {
            Write-Log "Creating new access profile: $profileName"
            if ($PSCmdlet.ShouldProcess("profile $profileName", 'Create NSP profile')) {
                $nspprofile = New-AzNetworkSecurityPerimeterProfile -ResourceGroupName $Resource_Group `
                    -SecurityPerimeterName $NSP_Name -Name $profileName
            }
        } else {
            Write-Log "Profile $profileName already exists, will update..."
        }
        
        # Add CIDR blocks to profile
        
        $ruleName = "databricks-nat-$region-rule"
        foreach ($cidr in $cidrs) {
            Write-Log "  Adding CIDR: $cidr"
        }
        # Pseudo-code for updating rule
        
        if (-not (Get-AzNetworkSecurityPerimeterAccessRule -Name $ruleName -ProfileName $profileName -ResourceGroupName $Resource_Group -SecurityPerimeterName $NSP_Name -ErrorAction SilentlyContinue)) {
            Write-Log "  Rule $ruleName does not exist"
            Write-Log "  Creating new rule $ruleName with CIDR blocks..." "SUCCESS"
        } else {
            Write-Log "  Rule $ruleName already exists" "WARNING"
            Write-Log "  Updating rule $ruleName with CIDR blocks..." "SUCCESS"
            # Delete existing rule before re-creating with updated CIDRs (since direct update may not be supported)
            $rule = Remove-AzNetworkSecurityPerimeterAccessRule -Name $ruleName -ProfileName $profileName -ResourceGroupName $Resource_Group -SecurityPerimeterName $NSP_Name
        }
        # Create new rule with updated CIDRs
        
        # Update profile with rules
        $rule = New-AzNetworkSecurityPerimeterAccessRule -Name $ruleName -ProfileName $profileName -ResourceGroupName $Resource_Group -SecurityPerimeterName $NSP_Name -AddressPrefix @($cidrs) -Direction 'Inbound'
        Write-Log "Profile '$profileName' configured with $($cidrs.Count) CIDR blocks" "SUCCESS"
    }
    
    
    Write-Log "Successfully created/updated NSP profiles for all regions" "SUCCESS"
    Write-Log "Script completed successfully!" "SUCCESS"
    
} catch {
    Write-Log "An error occurred: $_" "ERROR"
    Write-Log $_.Exception.StackTrace "ERROR"
    exit 1
}
