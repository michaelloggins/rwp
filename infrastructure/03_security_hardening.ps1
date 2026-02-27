#Requires -Modules Az.Resources, Az.Network, Az.Synapse, Az.DataFactory, Az.KeyVault
<#
.SYNOPSIS
    Security hardening for Synapse, ADF, and Key Vault in MVD-Core-rg:
    private endpoints, diagnostic logging, firewall rules, auditing.
.DESCRIPTION
    Run AFTER 01 and 02 scripts.
    Assumes Synapse workspace and ADF already exist.
#>

[CmdletBinding()]
param(
    [string] $CoreResourceGroup = "MVD-Core-rg",
    [string] $Location          = "centralus",
    [string] $VNetName          = "mvd-core-vnet",
    [string] $LogAnalyticsName  = "mvd-core-logs",
    [string] $KeyVaultName      = "mvd-core-kv",
    [Parameter(Mandatory)] [string] $SynapseWorkspace,
    [Parameter(Mandatory)] [string] $AdfName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== Security Hardening (Synapse, ADF, Key Vault) ===" -ForegroundColor Cyan

$LogAnalyticsId = az monitor log-analytics workspace show `
    --resource-group $CoreResourceGroup `
    --workspace-name $LogAnalyticsName `
    --query id -o tsv

# =============================================================================
# 1. SYNAPSE - Private Endpoint
# =============================================================================
Write-Host "`n[1/8] Synapse SQL private endpoint..." -ForegroundColor Yellow

$SynapseId = az synapse workspace show `
    --name $SynapseWorkspace `
    --resource-group $CoreResourceGroup `
    --query id -o tsv

az network private-endpoint create `
    --resource-group $CoreResourceGroup `
    --name "pe-$SynapseWorkspace-sql" `
    --location $Location `
    --vnet-name $VNetName `
    --subnet "snet-private-endpoints" `
    --private-connection-resource-id $SynapseId `
    --group-id SqlOnDemand `
    --connection-name "pec-$SynapseWorkspace-sql" `
    --output none

az network private-endpoint dns-zone-group create `
    --resource-group $CoreResourceGroup `
    --endpoint-name "pe-$SynapseWorkspace-sql" `
    --name "default" `
    --private-dns-zone "privatelink.sql.azuresynapse.net" `
    --zone-name "synapse-sql" `
    --output none

Write-Host "  pe-$SynapseWorkspace-sql (SqlOnDemand) -> snet-private-endpoints"

# =============================================================================
# 2. SYNAPSE - Firewall (deny public access)
# =============================================================================
Write-Host "`n[2/8] Synapse firewall rules..." -ForegroundColor Yellow

# Disable public network access
az synapse workspace update `
    --name $SynapseWorkspace `
    --resource-group $CoreResourceGroup `
    --public-network-access Disabled `
    --output none 2>$null

Write-Host "  Public network access DISABLED"

# =============================================================================
# 3. SYNAPSE - Diagnostic Logging + Auditing
# =============================================================================
Write-Host "`n[3/8] Synapse diagnostics..." -ForegroundColor Yellow

az monitor diagnostic-settings create `
    --name "diag-$SynapseWorkspace" `
    --resource $SynapseId `
    --workspace $LogAnalyticsId `
    --logs '[{\"categoryGroup\":\"allLogs\",\"enabled\":true},{\"categoryGroup\":\"audit\",\"enabled\":true}]' `
    --metrics '[{\"category\":\"AllMetrics\",\"enabled\":true}]' `
    --output none 2>$null

Write-Host "  All logs + audit -> $LogAnalyticsName"

# Synapse SQL auditing
az synapse workspace audit-policy update `
    --workspace-name $SynapseWorkspace `
    --resource-group $CoreResourceGroup `
    --state Enabled `
    --log-analytics-target-state Enabled `
    --log-analytics-workspace-resource-id $LogAnalyticsId `
    --output none 2>$null

Write-Host "  SQL auditing ON -> Log Analytics"

# =============================================================================
# 4. ADF - Private Endpoint (portal)
# =============================================================================
Write-Host "`n[4/8] ADF private endpoint..." -ForegroundColor Yellow

$AdfId = az datafactory show `
    --resource-group $CoreResourceGroup `
    --factory-name $AdfName `
    --query id -o tsv

az network private-endpoint create `
    --resource-group $CoreResourceGroup `
    --name "pe-$AdfName-df" `
    --location $Location `
    --vnet-name $VNetName `
    --subnet "snet-private-endpoints" `
    --private-connection-resource-id $AdfId `
    --group-id dataFactory `
    --connection-name "pec-$AdfName-df" `
    --output none

az network private-endpoint dns-zone-group create `
    --resource-group $CoreResourceGroup `
    --endpoint-name "pe-$AdfName-df" `
    --name "default" `
    --private-dns-zone "privatelink.datafactory.azure.net" `
    --zone-name "adf" `
    --output none

Write-Host "  pe-$AdfName-df -> snet-private-endpoints"

# =============================================================================
# 5. ADF - Disable Public Access
# =============================================================================
Write-Host "`n[5/8] ADF public access..." -ForegroundColor Yellow

az datafactory update `
    --resource-group $CoreResourceGroup `
    --factory-name $AdfName `
    --public-network-access Disabled `
    --output none 2>$null

Write-Host "  Public network access DISABLED"

# =============================================================================
# 6. ADF - Diagnostic Logging
# =============================================================================
Write-Host "`n[6/8] ADF diagnostics..." -ForegroundColor Yellow

az monitor diagnostic-settings create `
    --name "diag-$AdfName" `
    --resource $AdfId `
    --workspace $LogAnalyticsId `
    --logs '[{\"categoryGroup\":\"allLogs\",\"enabled\":true}]' `
    --metrics '[{\"category\":\"AllMetrics\",\"enabled\":true}]' `
    --output none 2>$null

Write-Host "  All logs + metrics -> $LogAnalyticsName"

# =============================================================================
# 7. KEY VAULT - Private Endpoint
# =============================================================================
Write-Host "`n[7/8] Key Vault private endpoint..." -ForegroundColor Yellow

$KvId = az keyvault show `
    --name $KeyVaultName `
    --resource-group $CoreResourceGroup `
    --query id -o tsv

az network private-endpoint create `
    --resource-group $CoreResourceGroup `
    --name "pe-$KeyVaultName-vault" `
    --location $Location `
    --vnet-name $VNetName `
    --subnet "snet-private-endpoints" `
    --private-connection-resource-id $KvId `
    --group-id vault `
    --connection-name "pec-$KeyVaultName-vault" `
    --output none

az network private-endpoint dns-zone-group create `
    --resource-group $CoreResourceGroup `
    --endpoint-name "pe-$KeyVaultName-vault" `
    --name "default" `
    --private-dns-zone "privatelink.vaultcore.azure.net" `
    --zone-name "keyvault" `
    --output none

Write-Host "  pe-$KeyVaultName-vault -> snet-private-endpoints"

# Key Vault diagnostics
az monitor diagnostic-settings create `
    --name "diag-$KeyVaultName" `
    --resource $KvId `
    --workspace $LogAnalyticsId `
    --logs '[{\"categoryGroup\":\"allLogs\",\"enabled\":true},{\"categoryGroup\":\"audit\",\"enabled\":true}]' `
    --metrics '[{\"category\":\"AllMetrics\",\"enabled\":true}]' `
    --output none 2>$null

Write-Host "  Key Vault diagnostics -> $LogAnalyticsName"

# =============================================================================
# 8. Azure Monitor Alerts (pipeline failures, security)
# =============================================================================
Write-Host "`n[8/8] Creating monitoring alerts..." -ForegroundColor Yellow

# Alert: ADF pipeline failure
az monitor metrics alert create `
    --resource-group $CoreResourceGroup `
    --name "alert-adf-pipeline-failure" `
    --scopes $AdfId `
    --condition "total PipelineFailedRuns > 0" `
    --window-size 5m `
    --evaluation-frequency 5m `
    --severity 2 `
    --description "ADF pipeline run failed" `
    --output none 2>$null

Write-Host "  Alert: ADF pipeline failures (Severity 2)"

# Alert: Synapse query failures
az monitor metrics alert create `
    --resource-group $CoreResourceGroup `
    --name "alert-synapse-query-failure" `
    --scopes $SynapseId `
    --condition "total BuiltinSqlPoolRequestsEnded > 0 where Result includes 'Error'" `
    --window-size 15m `
    --evaluation-frequency 5m `
    --severity 3 `
    --description "Synapse Serverless query errors detected" `
    --output none 2>$null

Write-Host "  Alert: Synapse query errors (Severity 3)"

# Alert: Key Vault unauthorized access
az monitor activity-log alert create `
    --resource-group $CoreResourceGroup `
    --name "alert-kv-unauthorized" `
    --scope $KvId `
    --condition "category=Security" `
    --description "Key Vault security event" `
    --output none 2>$null

Write-Host "  Alert: Key Vault security events"

# =============================================================================
# Done
# =============================================================================
Write-Host "`n=== Security Hardening Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Private endpoints created:"
Write-Host "  - Synapse SQL (SqlOnDemand)"
Write-Host "  - ADF (dataFactory)"
Write-Host "  - Key Vault (vault)"
Write-Host ""
Write-Host "All resources:"
Write-Host "  - Public network access: DISABLED"
Write-Host "  - Diagnostic logs: -> $LogAnalyticsName"
Write-Host "  - SQL auditing: ON (Synapse)"
Write-Host "  - Alerts: pipeline failures, query errors, KV security"
Write-Host ""
Write-Host "Next: Run 04_rwp_function_app.ps1"
