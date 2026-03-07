# Accepted Risk: localhost:3000 in CORS and EasyAuth Redirect URLs

**Finding ID:** INFO-4
**Date:** 2026-03-07
**Reviewed by:** Matt Loggins
**Status:** Accepted — will not fix at this time

## Finding

The production Function App configuration includes `https://localhost:3000` in two
places:

1. **CORS AllowedOrigins** — `host.json` (line 29) and Bicep `rwp-function-app.bicep`
   (line 95)
2. **EasyAuth allowedExternalRedirectUrls** — Bicep `rwp-function-app.bicep` (line 147)

The security assessment flagged this as an informational finding because development
origins should ideally not appear in production configuration.

## Why We Are Not Fixing This

### Single environment deployment

RWP is deployed to a single Azure environment (no separate dev/staging/prod). The
Function App is developed and tested locally using `func start`, which serves the app
on `https://localhost:3000`. Removing the localhost origin would require developers to
either:

- Deploy to Azure for every iteration (slow, expensive), or
- Maintain a separate host.json that is swapped at deploy time (added complexity with
  no security benefit given the controls below)

### Bicep `siteConfig.cors` overrides host.json

The CORS configuration in Bicep's `siteConfig` takes precedence over `host.json` at
the platform level. The `host.json` CORS block is only effective during local
development (`func start`). This means the `host.json` localhost entry has **zero
effect in production** — it is the Bicep-deployed configuration that matters.

The Bicep-deployed CORS list would need localhost removed separately, but the
compensating controls below make this unnecessary.

## Compensating Controls

| Control | Detail |
|---------|--------|
| **EasyAuth enforced** | All requests require valid Entra ID authentication regardless of origin. An attacker on localhost still cannot access the API without a valid token. |
| **Defense-in-depth auth guard** | `_require_authenticated()` in `function_app.py` rejects requests missing `X-MS-CLIENT-PRINCIPAL` even if EasyAuth were misconfigured. |
| **No wildcard or null origins** | CORS is restricted to two explicit origins: the production hostname and localhost. `SupportCredentials: true` is safe with explicit origins (the dangerous pattern is `"*"` or `"null"` with credentials). |
| **Audience validation** | EasyAuth validates the token audience matches `api://<clientId>`. A token obtained for a different app registration will be rejected. |
| **Group-based authorization** | Even with a valid token, users must be members of `sg-rwp-ePHI-Users` or `sg-rwp-CFO-Users` to access any data. |
| **localhost is not remotely exploitable** | `https://localhost:3000` only matches requests from a browser on the same machine. An external attacker cannot forge this origin from a remote host. A CSRF attack would require the victim to be running the dev server locally AND be authenticated to production. |

## Conditions for Remediation

This risk will be remediated when **either** of the following is implemented:

1. **Separate dev/prod environments** — A dedicated dev Function App deployment
   receives the localhost CORS origin; the production deployment does not.

2. **Bicep parameterization** — The `additionalCorsOrigins` array parameter is
   populated only in non-prod parameter files, keeping the production Bicep clean.
   Example:
   ```bicep
   param additionalCorsOrigins array = []
   cors: {
     allowedOrigins: union([
       'https://${functionAppName}.azurewebsites.net'
     ], additionalCorsOrigins)
   }
   ```

## HIPAA Relevance

This finding does not affect HIPAA compliance. The localhost origin does not weaken
authentication or authorization controls. All ePHI access requires Entra ID
authentication, security group membership, and passes through the same audit logging
regardless of request origin.
