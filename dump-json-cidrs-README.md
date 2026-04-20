## dump-json-cidrs.ps1 — Databricks Azure CIDR Dump Script

This script fetches the published Databricks IP ranges JSON feed and dumps the Azure outbound (NAT) CIDR prefixes, grouped by region. It is a read-only utility intended for quickly inspecting the current Databricks-advertised CIDRs when building firewall rules, NSG rules, or NSP configurations.

---

### How It Works

1. Downloads the Databricks IP ranges JSON from the specified URL (defaults to the public feed).
2. Filters the `prefixes` collection to Azure entries with `type = outbound`.
3. Groups the matching entries by region (or by platform when `global` is requested).
4. Prints the IPv4 CIDR prefixes for each region, one per line, comma-separated.

---

### Prerequisites

- PowerShell 5.1+ or PowerShell 7+
- Outbound network access to `https://www.databricks.com` (or to the URL supplied via `-InputURL`)

---

### Parameters

| Parameter | Required | Default | Description |
|---|---|---|---|
| `Regions` | No | `@("*")` | Region filter. Use `"*"` for all regions, `"global"` to group by platform, or one or more region names (e.g. `@("eastus","westus")`). |
| `InputURL` | No | `https://www.databricks.com/networking/v1/ip-ranges.json` | URL of the Databricks IP ranges JSON feed. |

---

### Examples

**Dump all Azure outbound CIDRs for every region:**
```powershell
./dump-json-cidrs.ps1
```

**Dump CIDRs for specific regions:**
```powershell
./dump-json-cidrs.ps1 -Regions *("eastus","westus2")
```

**Group all Azure outbound CIDRs globally (by platform):**
```powershell
./dump-json-cidrs.ps1 -Regions @("*")
```

**Use an alternate JSON source:**
```powershell
./dump-json-cidrs.ps1 -InputURL "https://example.com/custom-ip-ranges.json"
```

---

### Output

For each matching region, the script logs the region name and prints its IPv4 prefixes, comma-separated across lines. Example:

```
[2026-04-20 10:00:00] [INFO] Fetching Databricks IP ranges from https://www.databricks.com/networking/v1/ip-ranges.json
[2026-04-20 10:00:01] [INFO] Found 42 Azure outbound IPs
[2026-04-20 10:00:01] [INFO] Region: eastus
[2026-04-20 13:01:45] [default] Region: eastus
128.203.118.160/28,
128.203.119.128/25,
128.203.119.16/28,
128.203.119.48/28,
...
128.203.119.64/26
[2026-04-20 10:00:01] [SUCCESS] JSON data dumped successfully
```

If no Azure outbound IPs are returned by the feed, the script logs a warning and exits.

---

###### created by: Bruce Nelson, Databricks
