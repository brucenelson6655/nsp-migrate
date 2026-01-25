This script automates the creation of a Network Security Perimeter (NSP) in Azure and associates Storage Accounts with Databricks VNet ACLs to the NSP in learning mode. It logs all actions to a timestamped log file in the script's directory. 

## Parameters :

### Subscription_Id
    The Azure Subscription ID where the NSP will be created.
### Resource_Group
    The name of the Resource Group where the NSP will be created.
### Azure_Region
    The Azure region where the NSP will be created.
### Interactive
    (optional) Boolean flag to indicate whether to run in interactive mode (prompt for each association) or unattended mode.

### EXAMPLE
   ```
   ./nsp-migrate-script.ps1 -Subscription_Id "<subscription id>" -Resource_Group "<resource group name>" -Azure_Region "<azure region>"
   ```
