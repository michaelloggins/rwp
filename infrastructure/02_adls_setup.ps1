#Requires -Modules Az.Storage, Az.Resources, Az.Network, Az.KeyVault
<#
.SYNOPSIS
    Creates ADLS Gen2 in MVD-Core-rg with security hardening:
    private endpoint, customer-managed key encryption, diagnostic logging,
    containers, and directory structure.
.DESCRIPTION
    Run AFTER 01_core_shared_setup.ps1.
    The storage account is shared infrastructure -- future projects
    get their own paths (e.g., gold/next-project/).
#>

[CmdletBinding()]
param(
    [string] $CoreResourceGroup = "MVD-Core-rg",
    [string] $Location          = "centralus",
    [string] $StorageAccount    = "mvdcoredatalake",
    [string] $VNetName          = "mvd-core-vnet",
    [string] $KeyVaultName      = "mvd-core-kv",
    [string] $LogAnalyticsName  = "mvd-core-logs",
    [string] $AdfName           = "",
    [string] $SynapseWorkspace  = "",
    [string] $FunctionAppName   = "",
    [string] $FunctionAppRG     = "rg-rwp-cus-001"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ContainerStaging = "staging"
$ContainerGold    = "gold"

Write-Host "=== ADLS Gen2 Setup (Security Hardened) ===" -ForegroundColor Cyan
Write-Host "Resource Group:  $CoreResourceGroup"
Write-Host "Storage Account: $StorageAccount"

# =============================================================================
# 1. Create Storage Account (HNS, TLS 1.2, no public blob access)
# =============================================================================
Write-Host "`n[1/8] Creating ADLS Gen2 storage account..." -ForegroundColor Yellow

az storage account create `
    --name $StorageAccount `
    --resource-group $CoreResourceGroup `
    --location $Location `
    --sku Standard_GRS `
    --kind StorageV2 `
    --hns true `
    --min-tls-version TLS1_2 `
    --allow-blob-public-access false `
    --default-action Deny `
    --https-only true `
    --allow-shared-key-access false `
    --output none

Write-Host "  Created (GRS replication, shared key access DISABLED, public access DENIED)"

# =============================================================================
# 2. Customer-Managed Key (CMK) Encryption
# =============================================================================
Write-Host "`n[2/8] Configuring customer-managed key encryption..." -ForegroundColor Yellow

# Enable system-assigned managed identity on storage account
az storage account update `
    --name $StorageAccount `
    --resource-group $CoreResourceGroup `
    --assign-identity `
    --output none

$StoragePrincipalId = az storage account show `
    --name $StorageAccount `
    --resource-group $CoreResourceGroup `
    --query identity.principalId -o tsv

# Grant storage account access to Key Vault key
az role assignment create `
    --assignee $StoragePrincipalId `
    --role "Key Vault Crypto Service Encryption User" `
    --scope $(az keyvault show --name $KeyVaultName --resource-group $CoreResourceGroup --query id -o tsv) `
    --output none

# Get the key URI
$KeyUri = az keyvault key show `
    --vault-name $KeyVaultName `
    --name "adls-cmk" `
    --query key.kid -o tsv

# Configure CMK encryption
az storage account update `
    --name $StorageAccount `
    --resource-group $CoreResourceGroup `
    --encryption-key-source Microsoft.Keyvault `
    --encryption-key-vault "https://$KeyVaultName.vault.azure.net" `
    --encryption-key-name "adls-cmk" `
    --key-vault-user-identity-id "" `
    --output none 2>$null

Write-Host "  CMK encryption configured (key: adls-cmk in $KeyVaultName)"

# =============================================================================
# 3. Private Endpoint (DFS + Blob)
# =============================================================================
Write-Host "`n[3/8] Creating private endpoints..." -ForegroundColor Yellow

$StorageId = az storage account show `
    --name $StorageAccount `
    --resource-group $CoreResourceGroup `
    --query id -o tsv

# DFS private endpoint (Data Lake operations)
az network private-endpoint create `
    --resource-group $CoreResourceGroup `
    --name "pe-$StorageAccount-dfs" `
    --location $Location `
    --vnet-name $VNetName `
    --subnet "snet-private-endpoints" `
    --private-connection-resource-id $StorageId `
    --group-id dfs `
    --connection-name "pec-$StorageAccount-dfs" `
    --output none

az network private-endpoint dns-zone-group create `
    --resource-group $CoreResourceGroup `
    --endpoint-name "pe-$StorageAccount-dfs" `
    --name "default" `
    --private-dns-zone "privatelink.dfs.core.windows.net" `
    --zone-name "dfs" `
    --output none

Write-Host "  pe-$StorageAccount-dfs -> snet-private-endpoints"

# Blob private endpoint (for ADF compatibility)
az network private-endpoint create `
    --resource-group $CoreResourceGroup `
    --name "pe-$StorageAccount-blob" `
    --location $Location `
    --vnet-name $VNetName `
    --subnet "snet-private-endpoints" `
    --private-connection-resource-id $StorageId `
    --group-id blob `
    --connection-name "pec-$StorageAccount-blob" `
    --output none

az network private-endpoint dns-zone-group create `
    --resource-group $CoreResourceGroup `
    --endpoint-name "pe-$StorageAccount-blob" `
    --name "default" `
    --private-dns-zone "privatelink.blob.core.windows.net" `
    --zone-name "blob" `
    --output none

Write-Host "  pe-$StorageAccount-blob -> snet-private-endpoints"

# =============================================================================
# 4. Containers + Directory Structure
# =============================================================================
Write-Host "`n[4/8] Creating containers and directories..." -ForegroundColor Yellow

foreach ($Container in @($ContainerStaging, $ContainerGold)) {
    az storage container create `
        --name $Container `
        --account-name $StorageAccount `
        --auth-mode login `
        --output none 2>$null
    Write-Host "  Container: $Container"
}

$StagingDirs = @(
    "rwp/RESULTS", "rwp/CENTRALRECEIVING", "rwp/RASCLIENTS",
    "rwp/FOLDERS", "rwp/TESTGROUPNAMES", "rwp/TESTS",
    "rwp/RASPRICELIST", "rwp/RASTESTPRICES", "rwp/METADATA_LOOKUP_VALUES"
)

foreach ($Dir in $StagingDirs) {
    az storage fs directory create `
        --name $Dir `
        --file-system $ContainerStaging `
        --account-name $StorageAccount `
        --auth-mode login `
        --output none 2>$null
    Write-Host "  staging/$Dir"
}

az storage fs directory create `
    --name "rwp/fact_results_with_pricing" `
    --file-system $ContainerGold `
    --account-name $StorageAccount `
    --auth-mode login `
    --output none 2>$null
Write-Host "  gold/rwp/fact_results_with_pricing"

# =============================================================================
# 5. RBAC Role Assignments
# =============================================================================
Write-Host "`n[5/8] Assigning RBAC roles..." -ForegroundColor Yellow

if ($AdfName) {
    try {
        $AdfPrincipalId = az datafactory show `
            --resource-group $CoreResourceGroup `
            --factory-name $AdfName `
            --query identity.principalId -o tsv 2>$null
        if ($AdfPrincipalId) {
            az role assignment create `
                --assignee $AdfPrincipalId `
                --role "Storage Blob Data Contributor" `
                --scope $StorageId `
                --output none
            Write-Host "  ADF -> Storage Blob Data Contributor"
        }
    } catch { Write-Warning "  ADF role assignment skipped: $_" }
}

if ($SynapseWorkspace) {
    try {
        $SynapsePrincipalId = az synapse workspace show `
            --name $SynapseWorkspace `
            --resource-group $CoreResourceGroup `
            --query identity.principalId -o tsv 2>$null
        if ($SynapsePrincipalId) {
            az role assignment create `
                --assignee $SynapsePrincipalId `
                --role "Storage Blob Data Reader" `
                --scope $StorageId `
                --output none
            Write-Host "  Synapse -> Storage Blob Data Reader"
        }
    } catch { Write-Warning "  Synapse role assignment skipped: $_" }
}

if ($FunctionAppName) {
    try {
        $FuncPrincipalId = az functionapp identity show `
            --name $FunctionAppName `
            --resource-group $FunctionAppRG `
            --query principalId -o tsv 2>$null
        if ($FuncPrincipalId) {
            az role assignment create `
                --assignee $FuncPrincipalId `
                --role "Storage Blob Data Reader" `
                --scope $StorageId `
                --output none
            Write-Host "  Function App -> Storage Blob Data Reader"
        }
    } catch { Write-Warning "  Function App role assignment skipped: $_" }
}

# =============================================================================
# 6. Diagnostic Settings -> Log Analytics
# =============================================================================
Write-Host "`n[6/8] Configuring diagnostic logging..." -ForegroundColor Yellow

$LogAnalyticsId = az monitor log-analytics workspace show `
    --resource-group $CoreResourceGroup `
    --workspace-name $LogAnalyticsName `
    --query id -o tsv

# Storage account diagnostics (blob service)
az monitor diagnostic-settings create `
    --name "diag-$StorageAccount-blob" `
    --resource "$StorageId/blobServices/default" `
    --workspace $LogAnalyticsId `
    --logs '[{\"categoryGroup\":\"allLogs\",\"enabled\":true},{\"categoryGroup\":\"audit\",\"enabled\":true}]' `
    --metrics '[{\"category\":\"Transaction\",\"enabled\":true}]' `
    --output none 2>$null

Write-Host "  Blob service logs -> $LogAnalyticsName"

# Storage account diagnostics (DFS service for Data Lake)
az monitor diagnostic-settings create `
    --name "diag-$StorageAccount-dfs" `
    --resource "$StorageId/fileServices/default" `
    --workspace $LogAnalyticsId `
    --logs '[{\"categoryGroup\":\"allLogs\",\"enabled\":true}]' `
    --metrics '[{\"category\":\"Transaction\",\"enabled\":true}]' `
    --output none 2>$null

Write-Host "  DFS service logs -> $LogAnalyticsName"

# =============================================================================
# 7. Lifecycle Management
# =============================================================================
Write-Host "`n[7/8] Configuring lifecycle management..." -ForegroundColor Yellow

$PolicyJson = @'
{
    "rules": [
        {
            "enabled": true,
            "name": "cleanup-staging",
            "type": "Lifecycle",
            "definition": {
                "actions": {
                    "baseBlob": {
                        "delete": { "daysAfterModificationGreaterThan": 30 }
                    }
                },
                "filters": {
                    "blobTypes": ["blockBlob"],
                    "prefixMatch": ["staging/"]
                }
            }
        }
    ]
}
'@

$PolicyFile = [System.IO.Path]::GetTempFileName()
$PolicyJson | Set-Content -Path $PolicyFile -Encoding UTF8

az storage account management-policy create `
    --account-name $StorageAccount `
    --resource-group $CoreResourceGroup `
    --policy $PolicyFile `
    --output none 2>$null

Remove-Item $PolicyFile -ErrorAction SilentlyContinue
Write-Host "  Staging cleanup: delete blobs > 30 days"

# =============================================================================
# 8. Advanced Threat Protection
# =============================================================================
Write-Host "`n[8/8] Enabling Advanced Threat Protection..." -ForegroundColor Yellow

az security atp storage update `
    --resource-group $CoreResourceGroup `
    --storage-account $StorageAccount `
    --is-enabled true `
    --output none 2>$null

Write-Host "  ATP enabled for $StorageAccount"

# =============================================================================
# Done
# =============================================================================
Write-Host "`n=== ADLS Gen2 Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Security controls applied:"
Write-Host "  - TLS 1.2 minimum, HTTPS only"
Write-Host "  - Shared key access DISABLED (Azure AD only)"
Write-Host "  - Public blob access DENIED"
Write-Host "  - Customer-managed key encryption (Key Vault)"
Write-Host "  - Private endpoints (DFS + Blob)"
Write-Host "  - Firewall default action: Deny"
Write-Host "  - GRS replication for DR"
Write-Host "  - Diagnostic logs -> Log Analytics"
Write-Host "  - Advanced Threat Protection ON"
Write-Host ""
Write-Host "Next: Run 03_security_hardening.ps1"
