# Accepted Risk: Key Vault Public Network Access Enabled

**Finding ID:** INFO-3
**Date:** 2026-03-07
**Reviewed by:** Matt Loggins
**Status:** Accepted — will not fix at this time

## Finding

Azure Key Vault `kv-miravista-core` has `publicNetworkAccess: Enabled` in its Bicep
configuration (`infrastructure/bicep/modules/core-security.bicep`). The security
hardening assessment recommended setting this to `Disabled` to restrict access
exclusively to private endpoints.

## Why We Are Not Fixing This

Disabling public network access on Key Vault requires **all consumers** to resolve the
Key Vault's private endpoint via Azure Private DNS. Two consumers currently lack this:

1. **ADF Self-Hosted Integration Runtime** — Runs on an on-premises VM that does not
   have a DNS forwarder configured for `privatelink.vaultcore.azure.net`. The IR
   retrieves linked service secrets (e.g., StarLIMS SQL connection string) from KV
   at pipeline runtime. Disabling public access would break all ADF extract pipelines.

2. **Developer workstations** — Used for Bicep deployments, secret rotation, and
   operational tasks via `az keyvault` CLI commands. These workstations connect over
   VPN but do not resolve private DNS zones.

An IP-allowlist approach (`networkAcls.ipRules`) was considered but rejected because
both the IR VM and developer workstations use dynamic IP addresses that change on
DHCP renewal or VPN reconnection.

## Compensating Controls

The following controls are in place to mitigate the risk of public network access:

| Control | Detail |
|---------|--------|
| **RBAC authorization** | `enableRbacAuthorization: true` — no access policies; all access requires an explicit Entra ID role assignment |
| **Entra ID authentication** | All callers must authenticate via Entra ID (AAD); anonymous access is impossible |
| **Soft delete** | Enabled with 90-day retention — secrets cannot be permanently deleted without a separate purge operation |
| **Purge protection** | Enabled — even with the Key Vault Contributor role, secrets cannot be purged during the retention period |
| **Diagnostic logging** | All KV operations logged to Log Analytics (`diag-kv-miravista-core`) for audit and anomaly detection |
| **Private endpoint** | Exists (`pe-kv-miravista-core-vault`) for VNet-connected resources that can resolve private DNS |
| **No shared key access** | ADLS has `allowSharedKeyAccess: false`; KV secrets are the only path to service credentials |

## Conditions for Remediation

This risk will be remediated when **either** of the following is completed:

1. **Private DNS resolution** is available from the Self-Hosted IR and developer
   workstations (e.g., Azure DNS Private Resolver or conditional forwarder for
   `privatelink.vaultcore.azure.net`), **or**

2. **Static IPs** are assigned to the IR VM and developer VPN endpoints, enabling
   an IP-allowlist (`networkAcls.defaultAction: Deny` with `ipRules`).

## HIPAA Relevance

Key Vault stores infrastructure secrets (Synapse SQL admin password, database master
key) but does **not** store ePHI directly. Access to KV secrets alone does not grant
access to patient data — the Synapse serverless pool requires separate Entra ID
authentication and RBAC. The compensating controls satisfy §164.312(a)(1) Access
Control and §164.312(d) Person or Entity Authentication requirements.
