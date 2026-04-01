## nsp-check.ps1 — NSP Migration Pre-Check Script

This script identifies Azure Storage Accounts with Databricks VNet ACLs that are candidates for migration to a Network Security Perimeter (NSP). It produces a report of eligible accounts without making any changes, making it safe to run as a discovery/planning step before executing the full migration.

All actions are logged to a timestamped log file (`nsp-migrate-log_<timestamp>.log`) in the script's directory.

---

### How It Works 

1. Connects to the specified Azure subscription.
2. Queries Azure Resource Graph for Storage Accounts with VNet ACL rules pointing to known Databricks serverless subnet IDs.
3. Filters out accounts that are DBFS (workspace default storage) or already associated with an NSP.
4. Outputs a report listing the Storage Accounts that require NSP migration.


---

### Prerequisites

- [Azure PowerShell](https://learn.microsoft.com/en-us/powershell/azure/install-azure-powershell) (`Az` module)
- `Az.ResourceGraph` module (`Install-Module -Name Az.ResourceGraph`)
- Contributor or Owner access on the target subscription

---

### Parameters

| Parameter | Required | Description |
|---|---|---|
| `Subscription_Id` | Yes | The Azure Subscription ID to evaluate. |
| `Storage_Account_Names` | No | Array of specific Storage Account names to target. If omitted, all eligible Storage Accounts in the subscription are evaluated. |

---

### Examples

**Scan all Storage Accounts in a subscription:**
```powershell
./nsp-check.ps1 -Subscription_Id "12345678-1234-1234-1234-123456789012"
```

**Scan specific Storage Accounts:**
```powershell
./nsp-check.ps1 -Subscription_Id "12345678-1234-1234-1234-123456789012" -Storage_Account_Names "storageaccount1","storageaccount2"
```

---

### Output

The script prints a summary of Storage Accounts that:
- Have VNet ACL rules pointing to Databricks serverless subnets
- Are **not** DBFS (workspace default storage)
- Are **not** already associated with an NSP

Example output:
```
Found 3 Storage Accounts with Databricks VNet ACLs and not yet associated with NSP.
The following Storage Accounts were identified for migration:

- mystorageaccount1 Resource Group: my-rg Location: eastus
- mystorageaccount2 Resource Group: my-rg Location: westus2
- mystorageaccount3 Resource Group: another-rg Location: eastus
```

If no accounts require migration:
```
No Storage Accounts matched, no NSP work required.
```

---

### Next Steps

Once you have identified the Storage Accounts requiring migration, use [`nsp-migrate-script.ps1`](./README.md) to associate them with a Network Security Perimeter.

---

###### created by: Bruce Nelson, Databricks
