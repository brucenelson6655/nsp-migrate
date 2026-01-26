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
    Default is $true (interactive mode).
### Remove_Serverless_ServiceEndpoints
    (optional) Boolean flag to indicate whether to remove service endpoints from Storage Accounts after associating with NSP in unattended mode.
    Default is $false.  
### NSP_Name
    (optional) The name of the Network Security Perimeter to be created. Default is "databricks-nsp".
### NSP_Profile
    (optional) The name of the Network Security Perimeter Profile to be created. Default is "adb-profile".
### Storage_Account_Names
    (optional) An array of Storage Account names to specifically target for association. If not provided, all Storage Accounts with Databricks VNet ACLs will be processed.


### EXAMPLE
   #### To Run interactive
   ```
   ./nsp-migrate-script.ps1 -Subscription_Id "<subscription id>" -Resource_Group "<resource group name>" -Azure_Region "<azure region>"
```
   #### To run unattended : 
```
   ./nsp-migrate-script.ps1 -Subscription_Id "<subscription id>" -Resource_Group "<resource group name>" -Azure_Region "<azure region>" -Interactive False
```
   #### Remove Service endpoints in unattended mode 
```
   ./nsp-migrate-script.ps1 -Subscription_Id "<subscription id>" -Resource_Group "<resource group name>" -Azure_Region "<azure region>" -Interactive False -Remove_Serverless_ServiceEndpoints True
```
   #### To Migrate specific a storage account or storeage accounts 
   ```
   ./nsp-migrate-script.ps1 -Subscription_Id "<subscription id>" -Resource_Group "<resource group name>" -Azure_Region "<azure region>" -Storage_Account_Names <storage account or comma seperated list of storeage accounts>
```
