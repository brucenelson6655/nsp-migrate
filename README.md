### NSP (network security perimeters) for Azure Storage accounts used by serverless compute :

We are adding a new networking feature that introduces a NSP (networking security perimeter) and employs a service tag that labels inbound serverless service endpoint traffic subnets (serverless stable endpoints). This enables greater connectivity and flexibility, allowing for expansion without hitting current resource limitations.

### Motivation:

The increasing demand for serverless services requires the creation of additional compute subscriptions to support more Virtual Machines (VMs). A significant challenge arises because new subnets within these subscriptions cannot be automatically allowlisted by existing customers (due to existing product constraints). This prevents horizontal scale-out and causes sharp edges to product experience.

### Migration Script

This powershell script automates the creation of a Network Security Perimeter (NSP) in Azure and associates Storage Accounts with Databricks VNet ACLs to the NSP in learning mode. It logs all actions to a timestamped log file in the script's directory.

- If you wanted to use an ARM template method instead, there is an alternate migration script using ARM template for use in a CI/CD pipeline for example, follow this link : https://github.com/stjokerli/NPSforDatabricksServerless

### Parameters :

#### Subscription\_Id:

* The Azure Subscription ID where the NSP will be created.

#### Resource\_Group:

* The name of the Resource Group where the NSP will be created.

#### Azure\_Region:

* The Azure region where the NSP will be created.

#### Interactive:

* (optional) Boolean flag to indicate whether to run in interactive mode (prompt for each association) or unattended mode.  
* Default is $true (interactive mode).

#### Remove\_Serverless\_ServiceEndpoints:

* (optional) Boolean flag to indicate whether to remove service endpoints from Storage Accounts after associating with NSP in unattended mode.  
* The default is $false.  

#### NSP\_Name:

* (optional) The name of the Network Security Perimeter to be created. Default is "databricks-nsp".

#### NSP\_Profile:

* (optional) The name of the Network Security Perimeter Profile to be created. The default is "adb-profile".

#### Storage\_Account\_Names:

* (optional) An array of Storage Account names to specifically target for association. If not provided, all Storage Accounts with Databricks VNet ACLs will be processed.

### Running this script : 

You can run this script in the Azure portal cloud shell (powershell). When run without parameters it will prompt for the Subscription ID, resource group and region to use / create the NSP and profile for that specific subscription. 

You can modify the default NSP and profile names with the **NSP\_Name** and **NSP\_Profile** parameters. You can also target specific storage accounts by passing in a comma separated list of storage accounts  with the parameter **Storage\_Account\_Names**. 

#### Interactive and Unattended mode : 

This script can be run interactively which allows you to approve each change and step in the process, or you can run in unattended mode which will proceed to make changes without any prompting. This behavior is controlled  by the **Interactive** parameter with is defaulted to True (run interactively)

#### Deleting Serverless Service Endpoints (optional) : 

You have the option to delete the existing serverless service endpoints once the NSP is enabled. This action is not required and default is set to not delete after the NSP is associated. If you want to delete the serverless (stable) endpoint from your storage account once the NSP is associated, set **Remove\_Serverless\_ServiceEndpoints** to True. 


### EXAMPLES
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

###### created by: Bruce Nelson Databricks 