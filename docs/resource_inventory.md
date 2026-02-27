# RWP Resource Inventory

## Naming Convention

`{type}-{project}-{region}-{instance}`

Examples: `func-rwp-cus-001`, `rg-rwp-cus-001`, `asp-rwp-cus-001`

| Abbreviation | Meaning |
|---|---|
| rg | Resource Group |
| func | Function App |
| asp | App Service Plan |
| appi | Application Insights |
| st | Storage Account |
| alert | Metric/Activity Alert |

---

## Resource Groups

| Resource Group | Region | Purpose |
|---|---|---|
| **MVD-Core-rg** | Central US | Shared platform (networking, security, data lake, Synapse, ADF) |
| **rg-rwp-cus-001** | Central US | RWP project resources (Function App, dashboards) |

---

## MVD-Core-rg (Shared)

| # | Resource | Type | Name | Script |
|---|---|---|---|---|
| 1 | Virtual Network | Microsoft.Network/virtualNetworks | mvd-core-vnet (10.1.0.0/16) | 01 |
| 2 | Subnet | (under VNet) | snet-private-endpoints (10.1.1.0/24) | 01 |
| 3 | Subnet | (under VNet) | snet-adf-ir (10.1.2.0/24) | 01 |
| 4 | Subnet | (under VNet) | snet-functions (10.1.3.0/24) | 01 |
| 5 | Subnet | (under VNet) | snet-apps (10.1.4.0/24) | 01 |
| 6 | NSG | Microsoft.Network/networkSecurityGroups | nsg-private-endpoints | 01 |
| 7 | NSG | Microsoft.Network/networkSecurityGroups | nsg-functions | 01 |
| 8 | Log Analytics | Microsoft.OperationalInsights/workspaces | mvd-core-logs (90-day retention) | 01 |
| 9 | Key Vault | Microsoft.KeyVault/vaults | mvd-core-kv (purge-protected) | 01 |
| 10 | Encryption Key | (under Key Vault) | adls-cmk (RSA 2048) | 01 |
| 11-16 | Private DNS Zones | Microsoft.Network/privateDnsZones | 6 zones (blob, dfs, sql, adf, vault, websites) | 01 |
| 17-22 | DNS VNet Links | (under DNS Zones) | 6 links to mvd-core-vnet | 01 |
| 23 | ADLS Gen2 | Microsoft.Storage/storageAccounts | mvdcoredatalake (GRS, CMK, HNS) | 02 |
| 24 | Private Endpoint | Microsoft.Network/privateEndpoints | pe-mvdcoredatalake-dfs | 02 |
| 25 | Private Endpoint | Microsoft.Network/privateEndpoints | pe-mvdcoredatalake-blob | 02 |
| 26 | Private Endpoint | Microsoft.Network/privateEndpoints | pe-{synapse}-sql | 03 |
| 27 | Private Endpoint | Microsoft.Network/privateEndpoints | pe-{adf}-df | 03 |
| 28 | Private Endpoint | Microsoft.Network/privateEndpoints | pe-mvd-core-kv-vault | 03 |
| 29 | Metric Alert | Microsoft.Insights/metricAlerts | alert-adf-pipeline-failure | 03 |
| 30 | Metric Alert | Microsoft.Insights/metricAlerts | alert-synapse-query-failure | 03 |
| 31 | Activity Log Alert | Microsoft.Insights/activityLogAlerts | alert-kv-unauthorized | 03 |

**Pre-existing (not created by scripts):** Synapse Workspace, Data Factory

---

## rg-rwp-cus-001 (RWP Project)

| # | Resource | Type | Name | Script |
|---|---|---|---|---|
| 1 | Function App | Microsoft.Web/sites | func-rwp-cus-001 | 04 |
| 2 | App Service Plan | Microsoft.Web/serverfarms | asp-rwp-cus-001 (EP1, Linux) | 04 |
| 3 | Application Insights | Microsoft.Insights/components | appi-rwp-cus-001 | 04 |
| 4 | Storage Account | Microsoft.Storage/storageAccounts | strwpcus001 | 04 |
| 5 | Metric Alert | Microsoft.Insights/metricAlerts | alert-rwp-cus-001-errors | 04 |
| 6 | Metric Alert | Microsoft.Insights/metricAlerts | alert-rwp-cus-001-latency | 04 |

---

## Totals

| Resource Group | Resources |
|---|---|
| MVD-Core-rg | ~31 |
| rg-rwp-cus-001 | 6 |
| **Total** | **~37** |
