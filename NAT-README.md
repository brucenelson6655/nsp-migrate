
# Databricks IP Ranges

## Overview

The Databricks IP ranges JSON endpoint provides a comprehensive list of IP CIDR blocks used by Databricks across different platforms, regions, and traffic directions (inbound/outbound).

**Endpoint:** `https://www.databricks.com/networking/v1/ip-ranges.json`

## JSON Structure

```json
{
    "version": 1,
    "cidr_blocks": [
        {
            "cidr_block": "1.2.3.0/24",
            "region": "us-west-2",
            "platform": "AWS",
            "direction": "inbound",
            "description": "Databricks control plane"
        }
    ]
}
```

## Extract CIDR Ranges by Platform, Region, and Direction

### Python Example

```python
import requests

response = requests.get("https://www.databricks.com/networking/v1/ip-ranges.json")
data = response.json()

# Filter by platform, region, and direction
def get_cidr_ranges(platform, region, direction):
        return [
                block["cidr_block"]
                for block in data["cidr_blocks"]
                if (block["platform"] == platform and
                        block["region"] == region and
                        block["direction"] == direction)
        ]

# Example usage
ranges = get_cidr_ranges("AWS", "us-west-2", "inbound")
print(ranges)
```

### JavaScript Example

```javascript
const axios = require("axios");

async function getCidrRanges(platform, region, direction) {
    const { data } = await axios.get(
        "https://www.databricks.com/networking/v1/ip-ranges.json"
    );
    
    return data.cidr_blocks
        .filter(block => 
            block.platform === platform &&
            block.region === region &&
            block.direction === direction
        )
        .map(block => block.cidr_block);
}

getCidrRanges("AWS", "us-west-2", "inbound").then(console.log);
```

### Curl Example

For quick lookups using the command line and `jq`:

```bash
curl -s https://www.databricks.com/networking/v1/ip-ranges.json \
  | jq '.cidr_blocks[] | select(.platform=="AWS" and .region=="us-west-2" and .direction=="inbound") | .cidr_block'
```

This fetches the JSON and filters the CIDR blocks for the specified platform, region, and direction.
