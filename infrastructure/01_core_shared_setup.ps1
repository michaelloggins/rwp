#Requires -Modules Az.Resources, Az.Network, Az.KeyVault, Az.OperationalInsights
<#
.SYNOPSIS
    Creates shared infrastructure in MVD-Core-rg: VNet, subnets, NSGs,
    Key Vault, Log Analytics workspace, and Private DNS Zones.
.DESCRIPTION
    Run this FIRST. All other scripts depend on these resources.
    These resources are shared across RWP and future projects.
#>

[CmdletBinding()]
param(
    [string] $CoreResourceGroup = "MVD-Core-rg",
    [string] $Location          = "centralus",
    [string] $VNetName          = "mvd-core-vnet",
    [string] $KeyVaultName      = "mvd-core-kv",
    [string] $LogAnalyticsName  = "mvd-core-logs"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== MVD Core Shared Infrastructure ===" -ForegroundColor Cyan
Write-Host "Resource Group: $CoreResourceGroup"
Write-Host "Location:       $Location"

# =============================================================================
# 1. Resource Group
# =============================================================================
Write-Host "`n[1/6] Ensuring resource group exists..." -ForegroundColor Yellow

az group create `
    --name $CoreResourceGroup `
    --location $Location `
    --output none 2>$null

Write-Host "  $CoreResourceGroup ready."

# =============================================================================
# 2. Virtual Network + Subnets
# =============================================================================
Write-Host "`n[2/6] Creating VNet and subnets..." -ForegroundColor Yellow

# Main VNet: 10.1.0.0/16
az network vnet create `
    --resource-group $CoreResourceGroup `
    --name $VNetName `
    --location $Location `
    --address-prefix "10.1.0.0/16" `
    --output none

# Subnet: Private endpoints (ADLS, Synapse, ADF, Key Vault)
az network vnet subnet create `
    --resource-group $CoreResourceGroup `
    --vnet-name $VNetName `
    --name "snet-private-endpoints" `
    --address-prefix "10.1.1.0/24" `
    --disable-private-endpoint-network-policies true `
    --output none
Write-Host "  snet-private-endpoints (10.1.1.0/24)"

# Subnet: ADF Integration Runtime
az network vnet subnet create `
    --resource-group $CoreResourceGroup `
    --vnet-name $VNetName `
    --name "snet-adf-ir" `
    --address-prefix "10.1.2.0/24" `
    --output none
Write-Host "  snet-adf-ir (10.1.2.0/24)"

# Subnet: Function App VNet integration (requires delegation)
az network vnet subnet create `
    --resource-group $CoreResourceGroup `
    --vnet-name $VNetName `
    --name "snet-functions" `
    --address-prefix "10.1.3.0/24" `
    --delegations "Microsoft.Web/serverFarms" `
    --output none
Write-Host "  snet-functions (10.1.3.0/24) [delegated to Microsoft.Web]"

# Subnet: Future use (SWA, other apps)
az network vnet subnet create `
    --resource-group $CoreResourceGroup `
    --vnet-name $VNetName `
    --name "snet-apps" `
    --address-prefix "10.1.4.0/24" `
    --output none
Write-Host "  snet-apps (10.1.4.0/24)"

# =============================================================================
# 3. Network Security Groups
# =============================================================================
Write-Host "`n[3/6] Creating NSGs..." -ForegroundColor Yellow

# NSG for private endpoints subnet (deny all inbound by default, allow VNet)
az network nsg create `
    --resource-group $CoreResourceGroup `
    --name "nsg-private-endpoints" `
    --location $Location `
    --output none

az network nsg rule create `
    --resource-group $CoreResourceGroup `
    --nsg-name "nsg-private-endpoints" `
    --name "AllowVNetInbound" `
    --priority 100 `
    --direction Inbound `
    --access Allow `
    --protocol "*" `
    --source-address-prefixes "VirtualNetwork" `
    --destination-address-prefixes "*" `
    --destination-port-ranges "*" `
    --output none

az network nsg rule create `
    --resource-group $CoreResourceGroup `
    --nsg-name "nsg-private-endpoints" `
    --name "DenyAllInbound" `
    --priority 4096 `
    --direction Inbound `
    --access Deny `
    --protocol "*" `
    --source-address-prefixes "*" `
    --destination-address-prefixes "*" `
    --destination-port-ranges "*" `
    --output none

az network vnet subnet update `
    --resource-group $CoreResourceGroup `
    --vnet-name $VNetName `
    --name "snet-private-endpoints" `
    --network-security-group "nsg-private-endpoints" `
    --output none

Write-Host "  nsg-private-endpoints -> snet-private-endpoints"

# NSG for functions subnet
az network nsg create `
    --resource-group $CoreResourceGroup `
    --name "nsg-functions" `
    --location $Location `
    --output none

az network nsg rule create `
    --resource-group $CoreResourceGroup `
    --nsg-name "nsg-functions" `
    --name "AllowHTTPSInbound" `
    --priority 100 `
    --direction Inbound `
    --access Allow `
    --protocol Tcp `
    --source-address-prefixes "*" `
    --destination-address-prefixes "*" `
    --destination-port-ranges 443 `
    --output none

az network vnet subnet update `
    --resource-group $CoreResourceGroup `
    --vnet-name $VNetName `
    --name "snet-functions" `
    --network-security-group "nsg-functions" `
    --output none

Write-Host "  nsg-functions -> snet-functions"

# =============================================================================
# 4. Log Analytics Workspace
# =============================================================================
Write-Host "`n[4/6] Creating Log Analytics workspace..." -ForegroundColor Yellow

az monitor log-analytics workspace create `
    --resource-group $CoreResourceGroup `
    --workspace-name $LogAnalyticsName `
    --location $Location `
    --retention-time 90 `
    --output none

Write-Host "  $LogAnalyticsName (90-day retention)"

# =============================================================================
# 5. Key Vault (for CMK encryption keys, secrets)
# =============================================================================
Write-Host "`n[5/6] Creating Key Vault..." -ForegroundColor Yellow

az keyvault create `
    --resource-group $CoreResourceGroup `
    --name $KeyVaultName `
    --location $Location `
    --sku standard `
    --enable-purge-protection true `
    --enable-soft-delete true `
    --retention-days 90 `
    --enable-rbac-authorization true `
    --public-network-access Disabled `
    --output none

Write-Host "  $KeyVaultName (purge protection ON, public access OFF)"

# Create the CMK encryption key for ADLS
az keyvault key create `
    --vault-name $KeyVaultName `
    --name "adls-cmk" `
    --kty RSA `
    --size 2048 `
    --output none 2>$null

Write-Host "  Created encryption key 'adls-cmk'"

# =============================================================================
# 6. Private DNS Zones (for private endpoint name resolution)
# =============================================================================
Write-Host "`n[6/6] Creating Private DNS Zones..." -ForegroundColor Yellow

$DnsZones = @(
    "privatelink.blob.core.windows.net",       # ADLS / Blob
    "privatelink.dfs.core.windows.net",        # ADLS / DFS (Data Lake)
    "privatelink.sql.azuresynapse.net",        # Synapse SQL
    "privatelink.datafactory.azure.net",       # ADF
    "privatelink.vaultcore.azure.net",         # Key Vault
    "privatelink.azurewebsites.net"            # Function App
)

foreach ($Zone in $DnsZones) {
    az network private-dns zone create `
        --resource-group $CoreResourceGroup `
        --name $Zone `
        --output none 2>$null

    # Link DNS zone to VNet
    $LinkName = ($Zone -replace '\.', '-') + "-link"
    az network private-dns link vnet create `
        --resource-group $CoreResourceGroup `
        --zone-name $Zone `
        --name $LinkName `
        --virtual-network $VNetName `
        --registration-enabled false `
        --output none 2>$null

    Write-Host "  $Zone -> $VNetName"
}

# =============================================================================
# Done
# =============================================================================
Write-Host "`n=== Core Shared Infrastructure Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Resources created in $CoreResourceGroup :"
Write-Host "  VNet:           $VNetName (10.1.0.0/16)"
Write-Host "  Key Vault:      $KeyVaultName (public access disabled)"
Write-Host "  Log Analytics:  $LogAnalyticsName (90-day retention)"
Write-Host "  Private DNS:    6 zones linked to VNet"
Write-Host ""
Write-Host "Next: Run 02_adls_setup.ps1"
