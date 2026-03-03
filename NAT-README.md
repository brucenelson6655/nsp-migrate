
# Databricks IP Ranges

## Overview

The Databricks IP ranges JSON endpoint provides a comprehensive list of IP CIDR blocks used by Databricks across multiple cloud platforms, regions, services, and traffic directions.

**Endpoint:** `https://www.databricks.com/networking/v1/ip-ranges.json`

## JSON Structure

The current schema looks like the following example; it may grow additional fields over time but the core structure remains the same:

```json
{
  "timestampSeconds": 1770871875,
  "schemaVersion": "1.0",
  "prefixes": [
    {
      "platform": "aws",
      "region": "ap-northeast-1",
      "service": "Databricks",
      "type": "inbound",
      "ipv4Prefixes": [
        "18.99.67.176/28",
        "35.72.28.0/28"
      ],
      "ipv6Prefixes": []
    },
    {
      "platform": "aws",
      "region": "ap-northeast-1",
      "service": "Databricks",
      "type": "outbound",
      "ipv4Prefixes": [
        "18.177.16.95/32",
        "35.72.28.0/28",
        "52.195.231.0/24"
      ],
      "ipv6Prefixes": []
    }
    // ... more entries ...
  ]
}
```

Each object in `prefixes` describes a set of CIDR blocks for a given combination of **platform** (e.g. `aws`, `azure`, `gcp`), **region**, **service**, and **type** (`inbound` or `outbound`).


## Extract CIDR Ranges by Platform, Region, and Type

Below are simple examples that demonstrate filtering the current schema.  Adapt the logic to suit your language of choice.

### Python Example

```python
import requests

response = requests.get("https://www.databricks.com/networking/v1/ip-ranges.json")
data = response.json()

# Filter prefixes by platform, region and traffic type (inbound/outbound)
def get_prefixes(platform, region, traffic_type):
    return [
        p
        for p in data["prefixes"]
        if (
            p["platform"] == platform
            and p["region"] == region
            and p["type"] == traffic_type
        )
    ]

# Example usage – get all IPv4 ranges for AWS us-west-2 inbound
prefixes = get_prefixes("aws", "us-west-2", "inbound")
ipv4_list = prefixes[0]["ipv4Prefixes"] if prefixes else []
print(ipv4_list)
```

### JavaScript Example

```javascript
const axios = require("axios");

async function getPrefixes(platform, region, trafficType) {
    const { data } = await axios.get(
        "https://www.databricks.com/networking/v1/ip-ranges.json"
    );

    return data.prefixes
        .filter(p =>
            p.platform === platform &&
            p.region === region &&
            p.type === trafficType
        );
}

getPrefixes("aws", "us-west-2", "inbound").then(prefixes => {
    const ipv4s = prefixes.flatMap(p => p.ipv4Prefixes || []);
    console.log(ipv4s);
});
```

### PowerShell Example

```powershell
# Fetch the JSON and parse it
$json = Invoke-RestMethod -Uri "https://www.databricks.com/networking/v1/ip-ranges.json"

# Function to filter prefixes
function Get-Prefixes {
    param(
        [string]$Platform,
        [string]$Region,
        [string]$Type
    )
    $json.prefixes |
        Where-Object {
            $_.platform -eq $Platform -and
            $_.region -eq $Region -and
            $_.type -eq $Type
        }
}

# Example: AWS us-west-2 inbound IPv4 prefixes
$results = Get-Prefixes -Platform 'aws' -Region 'us-west-2' -Type 'outbound'
$ipv4 = $results | Select-Object -ExpandProperty ipv4Prefixes
$ipv4
```

### Curl Example

```bash
curl -s https://www.databricks.com/networking/v1/ip-ranges.json \
  | jq '.prefixes[] | select(.platform=="aws" and .region=="us-west-2" and .type=="inbound") | .ipv4Prefixes[]'
```

The command fetches JSON and prints the IPv4 prefixes matching the given platform, region and type.
