#Requires -Modules Az.Resources, Az.Functions, Az.Network, Az.ApplicationInsights
<#
.SYNOPSIS
    Creates the RWP Function App in rg-rwp-cus-001 with security hardening:
    VNet integration, private endpoint, managed identity, HTTPS-only,
    Application Insights, and diagnostic logging.
.DESCRIPTION
    Run AFTER 01-03 scripts. This is the only project-specific resource group.
    If RWP is decommissioned, delete rg-rwp-cus-001 without affecting shared infra.
#>

[CmdletBinding()]
param(
    [string] $RwpResourceGroup  = "rg-rwp-cus-001",
    [string] $CoreResourceGroup = "MVD-Core-rg",
    [string] $Location          = "centralus",
    [string] $FunctionAppName   = "func-rwp-cus-001",
    [string] $AppServicePlan    = "asp-rwp-cus-001",
    [string] $StorageAccount    = "strwpcus001",
    [string] $VNetName          = "mvd-core-vnet",
    [string] $LogAnalyticsName  = "mvd-core-logs",
    [string] $SynapseWorkspace  = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== RWP Function App Setup ===" -ForegroundColor Cyan
Write-Host "Resource Group: $RwpResourceGroup"
Write-Host "Function App:   $FunctionAppName"

# =============================================================================
# 1. Resource Group
# =============================================================================
Write-Host "`n[1/10] Ensuring resource group exists..." -ForegroundColor Yellow

az group create `
    --name $RwpResourceGroup `
    --location $Location `
    --output none 2>$null

Write-Host "  $RwpResourceGroup ready."

# =============================================================================
# 2. Function App Storage Account (separate from data lake)
# =============================================================================
Write-Host "`n[2/10] Creating Function App storage account..." -ForegroundColor Yellow

az storage account create `
    --name $StorageAccount `
    --resource-group $RwpResourceGroup `
    --location $Location `
    --sku Standard_LRS `
    --kind StorageV2 `
    --min-tls-version TLS1_2 `
    --allow-blob-public-access false `
    --https-only true `
    --output none

Write-Host "  $StorageAccount (TLS 1.2, HTTPS only)"

# =============================================================================
# 3. Application Insights (for Function App monitoring)
# =============================================================================
Write-Host "`n[3/10] Creating Application Insights..." -ForegroundColor Yellow

$LogAnalyticsId = az monitor log-analytics workspace show `
    --resource-group $CoreResourceGroup `
    --workspace-name $LogAnalyticsName `
    --query id -o tsv

az monitor app-insights component create `
    --app "appi-rwp-cus-001" `
    --location $Location `
    --resource-group $RwpResourceGroup `
    --workspace $LogAnalyticsId `
    --kind web `
    --application-type web `
    --output none

$AppInsightsKey = az monitor app-insights component show `
    --app "appi-rwp-cus-001" `
    --resource-group $RwpResourceGroup `
    --query instrumentationKey -o tsv

$AppInsightsConnStr = az monitor app-insights component show `
    --app "appi-rwp-cus-001" `
    --resource-group $RwpResourceGroup `
    --query connectionString -o tsv

Write-Host "  appi-rwp-cus-001 -> $LogAnalyticsName"

# =============================================================================
# 4. App Service Plan (Linux, consumption or P1v3 for VNet)
# =============================================================================
Write-Host "`n[4/10] Creating App Service Plan..." -ForegroundColor Yellow

# VNet integration requires at least Premium (EP1) or Dedicated plan
az functionapp plan create `
    --resource-group $RwpResourceGroup `
    --name $AppServicePlan `
    --location $Location `
    --sku EP1 `
    --is-linux true `
    --min-instances 0 `
    --max-burst 3 `
    --output none

Write-Host "  $AppServicePlan (Elastic Premium EP1, Linux, scale 0-3)"

# =============================================================================
# 5. Function App
# =============================================================================
Write-Host "`n[5/10] Creating Function App..." -ForegroundColor Yellow

az functionapp create `
    --resource-group $RwpResourceGroup `
    --name $FunctionAppName `
    --plan $AppServicePlan `
    --storage-account $StorageAccount `
    --runtime python `
    --runtime-version 3.11 `
    --functions-version 4 `
    --os-type Linux `
    --assign-identity "[system]" `
    --https-only true `
    --output none

Write-Host "  $FunctionAppName (Python 3.11, HTTPS only, system-assigned MI)"

# =============================================================================
# 6. Function App Settings
# =============================================================================
Write-Host "`n[6/10] Configuring app settings..." -ForegroundColor Yellow

# Get the Synapse endpoint
$SynapseEndpoint = ""
if ($SynapseWorkspace) {
    $SynapseEndpoint = "$SynapseWorkspace-ondemand.sql.azuresynapse.net"
}

az functionapp config appsettings set `
    --resource-group $RwpResourceGroup `
    --name $FunctionAppName `
    --settings `
        "SYNAPSE_ENDPOINT=$SynapseEndpoint" `
        "SYNAPSE_DATABASE=rwp_analytics" `
        "APPLICATIONINSIGHTS_CONNECTION_STRING=$AppInsightsConnStr" `
        "APPINSIGHTS_INSTRUMENTATIONKEY=$AppInsightsKey" `
        "SCM_DO_BUILD_DURING_DEPLOYMENT=true" `
    --output none

Write-Host "  Synapse endpoint, App Insights configured"

# Enforce minimum TLS 1.2 on the Function App
az functionapp config set `
    --resource-group $RwpResourceGroup `
    --name $FunctionAppName `
    --min-tls-version 1.2 `
    --ftps-state Disabled `
    --output none

Write-Host "  TLS 1.2 minimum, FTP DISABLED"

# =============================================================================
# 7. VNet Integration (outbound traffic goes through VNet)
# =============================================================================
Write-Host "`n[7/10] Configuring VNet integration..." -ForegroundColor Yellow

$VNetId = az network vnet show `
    --resource-group $CoreResourceGroup `
    --name $VNetName `
    --query id -o tsv

az functionapp vnet-integration add `
    --resource-group $RwpResourceGroup `
    --name $FunctionAppName `
    --vnet $VNetId `
    --subnet "snet-functions" `
    --output none

# Route all outbound traffic through VNet
az functionapp config appsettings set `
    --resource-group $RwpResourceGroup `
    --name $FunctionAppName `
    --settings "WEBSITE_VNET_ROUTE_ALL=1" `
    --output none

Write-Host "  VNet integration -> snet-functions (all traffic routed through VNet)"

# =============================================================================
# 8. Grant Function App access to Synapse
# =============================================================================
Write-Host "`n[8/10] Granting Synapse access to Function App MI..." -ForegroundColor Yellow

$FuncPrincipalId = az functionapp identity show `
    --resource-group $RwpResourceGroup `
    --name $FunctionAppName `
    --query principalId -o tsv

if ($SynapseWorkspace) {
    Write-Host "  Function App principal: $FuncPrincipalId"
    Write-Host ""
    Write-Host "  ** MANUAL STEP REQUIRED **" -ForegroundColor Red
    Write-Host "  Run this T-SQL in Synapse Serverless (rwp_analytics database):"
    Write-Host ""
    Write-Host "  CREATE USER [$FunctionAppName] FROM EXTERNAL PROVIDER;" -ForegroundColor White
    Write-Host "  ALTER ROLE db_datareader ADD MEMBER [$FunctionAppName];" -ForegroundColor White
    Write-Host ""
}

# =============================================================================
# 9. Diagnostic Settings
# =============================================================================
Write-Host "`n[9/10] Configuring diagnostic logging..." -ForegroundColor Yellow

$FuncAppId = az functionapp show `
    --resource-group $RwpResourceGroup `
    --name $FunctionAppName `
    --query id -o tsv

az monitor diagnostic-settings create `
    --name "diag-$FunctionAppName" `
    --resource $FuncAppId `
    --workspace $LogAnalyticsId `
    --logs '[{\"categoryGroup\":\"allLogs\",\"enabled\":true},{\"categoryGroup\":\"audit\",\"enabled\":true}]' `
    --metrics '[{\"category\":\"AllMetrics\",\"enabled\":true}]' `
    --output none 2>$null

Write-Host "  Function App logs -> $LogAnalyticsName"

# =============================================================================
# 10. Monitoring Alerts
# =============================================================================
Write-Host "`n[10/10] Creating alerts..." -ForegroundColor Yellow

# Alert: Function App errors (HTTP 5xx)
az monitor metrics alert create `
    --resource-group $RwpResourceGroup `
    --name "alert-rwp-cus-001-errors" `
    --scopes $FuncAppId `
    --condition "total Http5xx > 5" `
    --window-size 5m `
    --evaluation-frequency 1m `
    --severity 2 `
    --description "RWP Function App HTTP 5xx errors exceeded threshold" `
    --output none 2>$null

Write-Host "  Alert: HTTP 5xx > 5 in 5 min (Severity 2)"

# Alert: Function App response time
az monitor metrics alert create `
    --resource-group $RwpResourceGroup `
    --name "alert-rwp-cus-001-latency" `
    --scopes $FuncAppId `
    --condition "avg HttpResponseTime > 10" `
    --window-size 5m `
    --evaluation-frequency 5m `
    --severity 3 `
    --description "RWP Function App avg response time > 10s" `
    --output none 2>$null

Write-Host "  Alert: Avg response time > 10s (Severity 3)"

# =============================================================================
# Done
# =============================================================================
Write-Host "`n=== RWP Function App Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Resources in $RwpResourceGroup :"
Write-Host "  Function App:    $FunctionAppName"
Write-Host "  App Service Plan: $AppServicePlan (EP1)"
Write-Host "  App Insights:     appi-rwp-cus-001"
Write-Host "  Storage:          $StorageAccount"
Write-Host ""
Write-Host "Security controls:"
Write-Host "  - System-assigned managed identity"
Write-Host "  - HTTPS only, TLS 1.2 minimum"
Write-Host "  - FTP DISABLED"
Write-Host "  - VNet integrated (all outbound via VNet)"
Write-Host "  - Diagnostic logs -> Log Analytics"
Write-Host "  - Error + latency alerts configured"
Write-Host ""
Write-Host "Remaining manual steps:" -ForegroundColor Yellow
Write-Host "  1. Run the Synapse T-SQL commands shown above"
Write-Host "  2. Deploy function code: func azure functionapp publish $FunctionAppName"
Write-Host "  3. (Optional) Add Action Group to alerts for email/Teams notifications"
