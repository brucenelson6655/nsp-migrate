# NAT NSP Deploy (nat-nsp-deploy.ps1)

This script deploys or updates a Network Security Perimeter (NSP) configuration across one or more Azure regions using the project's NSP tooling.

**What it does:**
- Deploys NSP resources for a given subscription, resource group and NSP name.
- Targets one or more regions (multi-region deployment supported).

**Prerequisites:**
- PowerShell 7+ or Windows PowerShell with required Az modules installed.
- Signed-in Azure account with sufficient permissions to create/modify networking and resource-group scoped resources.
- `nat-nsp-deploy.ps1` must be present in the current working directory.

**Common parameters:**
- `-Subscription_Id` : Azure subscription GUID to target.
- `-Resource_Group` : Name of the resource group containing the NSP.
- `-NSP_Name` : The Existing Network Security Perimeter name to update (e.g., `databricks-nsp`). 
   - NOTE: The NSP needs to be created ahead of time either manually or by using the nsp-migrate-script.ps1 in this repository. 
- `-Regions` : An array of Azure regions to target (e.g., `@("westus","eastus")`). Use `"*"` for all regions.
- `-NSP_ProfileNamePrefix` : *(optional)* prefix used when creating region-specific profiles (default: `databricks-nat`).
- `-NSP_Profile` : *(optional)* single profile name; if set, all IPs are added to this profile and `-NSP_ProfileNamePrefix` is ignored.


**Example usage: (regional profiles)**
```powershell
./nat-nsp-deploy.ps1 \
	-SubscriptionId "########-####-####-####-############" \
	-NetworkSecurityPerimeterName "databricks-nsp" \
	-ResourceGroupName "brn-common-wus" \
	-Regions @("westus", "westus2", "eastus", "eastus2")
```


**Example usage: (single profile)**
```powershell
./nat-nsp-deploy.ps1 \
	-SubscriptionId "########-####-####-####-############" \
	-NetworkSecurityPerimeterName "databricks-nsp" \
    -Profile_Name "databricks-NAT"
	-ResourceGroupName "brn-common-wus" \
	-Regions @("westus", "westus2", "eastus", "eastus2")
```

**Notes & troubleshooting:**
- If you see an error like "An expression was expected after '('", check the script for unbalanced parentheses or unfinished subexpressions (`$(...)`).
- Ensure the account running the script has `Contributor` (or the required RBAC role) on the target subscription/resource group.
- If a deployment fails in one region, investigate the generated logs/outputs and re-run for that region after fixing issues.

**Where to look for more info:**
- See the script header comments inside `nat-nsp-deploy.ps1` for implementation details and additional parameters.

If you want, I can: update parameter descriptions with exact names from the script, add a troubleshooting section tailored to errors the script produces, or rename this file to `nat-nsp-deploy-README.md`.
    