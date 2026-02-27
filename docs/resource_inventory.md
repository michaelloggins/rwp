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
| syn | Synapse Workspace |
| adf | Azure Data Factory |
| alert | Metric/Activity Alert |

---

## Resource Groups

| Resource Group | Region | Purpose |
|---|---|---|
| **MVD-Core-rg** | Central US | Shared platform (networking, security, data lake, Synapse, ADF) |
| **rg-rwp-cus-001** | Central US | RWP project resources (Function App, dashboards) |

---

## Network Allocation (from AzureIPAM)

VNet: `vnet-miravista-core` (10.102.0.0/16, MVD-Core-rg)

| Subnet | CIDR | Purpose | Status |
|---|---|---|---|
| snet-private-endpoints | 10.102.1.0/24 | ADLS, Synapse, ADF, KV private endpoints | Existing |
| snet-functions | 10.102.2.0/24 | Azure Functions VNet integration | New (Bicep) |
| snet-adf-ir | 10.102.3.0/24 | ADF Integration Runtime | New (Bicep) |
| snet-apps | 10.102.4.0/24 | Future app services (SWA, etc.) | New (Bicep) |

---

## MVD-Core-rg (Shared)

### Pre-Existing (referenced, not created by Bicep)

| # | Resource | Type | Name |
|---|---|---|---|
| 1 | Virtual Network | Microsoft.Network/virtualNetworks | vnet-miravista-core (10.102.0.0/16) |
| 2 | Subnet | (under VNet) | snet-private-endpoints (10.102.1.0/24) |
| 3 | Log Analytics | Microsoft.OperationalInsights/workspaces | log-miravista-core (90-day retention) |
| 4 | Key Vault | Microsoft.KeyVault/vaults | kv-miravista-core (RBAC auth) |
| 5-7 | Private DNS Zones | Microsoft.Network/privateDnsZones | blob, vault, websites (with VNet links) |

### Created by Bicep

| # | Resource | Type | Name | Module |
|---|---|---|---|---|
| 1 | Subnet | (under VNet) | snet-functions (10.102.2.0/24) | core-networking |
| 2 | Subnet | (under VNet) | snet-adf-ir (10.102.3.0/24) | core-networking |
| 3 | Subnet | (under VNet) | snet-apps (10.102.4.0/24) | core-networking |
| 4 | NSG | Microsoft.Network/networkSecurityGroups | nsg-functions | core-networking |
| 5-7 | Private DNS Zones | Microsoft.Network/privateDnsZones | dfs, sql, adf (with VNet links) | core-networking |
| 8 | Encryption Key | (under Key Vault) | adls-cmk (RSA 2048) | core-security |
| 9 | Private Endpoint | Microsoft.Network/privateEndpoints | pe-kv-miravista-core-vault | core-security |
| 10 | User-Assigned Identity | Microsoft.ManagedIdentity | id-mvdcoredatalake | adls |
| 11 | ADLS Gen2 | Microsoft.Storage/storageAccounts | mvdcoredatalake (GRS, CMK, HNS) | adls |
| 12 | Private Endpoint | Microsoft.Network/privateEndpoints | pe-mvdcoredatalake-dfs | adls |
| 13 | Private Endpoint | Microsoft.Network/privateEndpoints | pe-mvdcoredatalake-blob | adls |
| 14 | Synapse Workspace | Microsoft.Synapse/workspaces | syn-mvd-cus-001 | synapse |
| 15 | Data Factory | Microsoft.DataFactory/factories | adf-mvd-cus-001 | adf |
| 16 | Private Endpoint | Microsoft.Network/privateEndpoints | pe-syn-mvd-cus-001-sql | security-hardening |
| 17 | Private Endpoint | Microsoft.Network/privateEndpoints | pe-adf-mvd-cus-001-df | security-hardening |
| 18 | Metric Alert | Microsoft.Insights/metricAlerts | alert-adf-pipeline-failure | security-hardening |
| 19 | Metric Alert | Microsoft.Insights/metricAlerts | alert-synapse-query-failure | security-hardening |

---

## rg-rwp-cus-001 (RWP Project)

| # | Resource | Type | Name | Module |
|---|---|---|---|---|
| 1 | Function App | Microsoft.Web/sites | func-rwp-cus-001 | rwp-function-app |
| 2 | App Service Plan | Microsoft.Web/serverfarms | asp-rwp-cus-001 (EP1, Linux) | rwp-function-app |
| 3 | Application Insights | Microsoft.Insights/components | appi-rwp-cus-001 | rwp-function-app |
| 4 | Storage Account | Microsoft.Storage/storageAccounts | strwpcus001 | rwp-function-app |
| 5 | Metric Alert | Microsoft.Insights/metricAlerts | alert-rwp-cus-001-errors | rwp-function-app |
| 6 | Metric Alert | Microsoft.Insights/metricAlerts | alert-rwp-cus-001-latency | rwp-function-app |

---

## ADLS Container Structure

Storage Account: `mvdcoredatalake`

| Container | Purpose |
|---|---|
| staging | Raw Parquet extracts from StarLIMS (auto-cleaned after 30 days) |
| gold | Curated fact tables (fact_results_with_pricing, partitioned by year) |
| synapse | Synapse workspace default filesystem (metadata, temp data) |

---

## Totals

| Resource Group | Pre-Existing | Created by Bicep |
|---|---|---|
| MVD-Core-rg | 7 | 19 |
| rg-rwp-cus-001 | 0 | 6 |
| **Total** | **7** | **25** |
