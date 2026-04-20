param (
[Parameter(Mandatory=$false)]
    [string[]]$Regions = @("*"), # "*" for all regions, or specify specific regions like @("eastus", "westus")
[Parameter(Mandatory=$false)]
    [string]$InputURL = "https://www.databricks.com/networking/v1/ip-ranges.json" # Default input URL
)


function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARNING","ERROR","SUCCESS")] [string]$Level = "default"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Level) {
        "INFO"    { Write-Host "[$timestamp] [$Level] $Message" }
        "WARNING" { Write-Warning "[$timestamp] $Message" }
        "ERROR"   { Write-Error "[$timestamp] $Message" }
        "SUCCESS" { Write-Host -ForegroundColor Green "[$timestamp] [SUCCESS] $Message" }
        default    { Write-Host -ForegroundColor DarkCyan "[$timestamp] [$Level] $Message" }
    }
}

function collectJSONIPs {
    param (
        [ValidateSet("outbound", "serviceendpoint")]
        [string]$nsptype # "outbound" or "serviceendpoint"
    )
    
    Write-Log "Filtering for Azure inbound NAT traffic..."
    $azureNatIps = $response.prefixes | Where-Object {
        $_.platform -eq "azure" -and $_.type -eq $nsptype
    }
    
    if (-not $azureNatIps.ipv4Prefixes -or $azureNatIps.ipv4Prefixes.Count -eq 0) {
        Write-Log "No Azure outbound IPs found!" "WARNING"
        exit 0
    }
    
    Write-Log "Found $($azureNatIps.ipv4Prefixes.Count) Azure outbound IPs"

     
    # Step 3: Group by region
    if ($REgions[0] -eq "global") {
        $ipsByRegion = $azureNatIps | Group-Object -Property platform
    } else {
        $ipsByRegion = $azureNatIps | Group-Object -Property region
    }
    

    return $ipsByRegion
}

Write-Log "Fetching Databricks IP ranges from $InputURL"
$response = Invoke-RestMethod -Uri $InputURL -Method Get

$ipsByRegion = collectJSONIPs -nsptype "outbound"
Write-Log "IPs grouped by region: $($ipsByRegion.Count) regions" 
# lets get a list of the regions

if (($Regions[0] -ne "*") -and ($Regions[0] -ne "global")) {
        $ipsByRegion = $ipsByRegion | Where-Object { $_.Name -in $Regions }
        Write-Log "Filtered to $($ipsByRegion.Count) requested regions: $($Regions -join ', ')"
}

$JSON_locations = $ipsByRegion | ForEach-Object { $_.Name }
Write-Log "Regions in JSON data: $($JSON_locations -join ', ')"

foreach ($region in $ipsByRegion) {
    Write-Log "Region: $($region.Name)"
    # foreach ($prefix in $region.Group.ipv4Prefixes) {
    #     Write-Host "$prefix,"
    # }
    $region.Group.ipv4Prefixes -join ",`n" | Write-Host
}

Write-Log "JSON data dumped successfully" "SUCCESS"