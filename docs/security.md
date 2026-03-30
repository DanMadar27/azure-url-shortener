# Security

## Secrets Management

- All secrets are stored in **Azure Key Vault** and fetched at runtime via managed identity — no secrets exist in app settings, environment variables, or source code.
- The `api-key` secret is a randomly generated UUID created by Terraform's `random_uuid` resource.
- Redis authentication uses **Entra ID tokens** obtained via managed identity — no Redis password is ever stored or transmitted as a static credential.
- Key Vault uses the RBAC authorization model. The App Service identity holds `Key Vault Secrets User` (read-only). The deploying user holds `Key Vault Secrets Officer` (can create/update secrets). No legacy access policies are used.

## Network Security

- **Redis** has `public_network_access_enabled = false` — it has no public endpoint and is reachable only via its private endpoint inside the VNet.
- **App Service inbound** is restricted by IP allowlist (configured via `allowed_ip_cidrs` Terraform variable). All traffic from other IPs receives 403 before reaching the application.
- **App Service outbound** is routed through VNet Integration with `WEBSITE_VNET_ROUTE_ALL=1` — all egress (Redis, Key Vault, Entra ID token endpoint) flows through the private network.
- All traffic uses **TLS 1.2 minimum** (enforced on App Service, Redis, and Key Vault).
- NSG on `redis-subnet` allows only TCP 6380 inbound from `app-subnet` and denies everything else.

## Identity

- App Service uses a **system-assigned managed identity** — no service principal credentials to store, rotate, or leak. Azure handles the full token lifecycle.
- **Principle of least privilege**: the managed identity holds only `Key Vault Secrets User` and `Redis Data Owner` — no broader permissions.

## Known Risks and Mitigations


| Risk                                                             | Current state         | Production mitigation                                             |
| ---------------------------------------------------------------- | --------------------- | ----------------------------------------------------------------- |
| IP allowlisting is weak perimeter control                        | Implemented           | Add Azure Front Door + WAF (OWASP ruleset) at the edge            |
| Single shared API key — if leaked, all consumers are compromised | Implemented           | Per-consumer API keys with rotation; or OAuth2 client credentials |
| No audit logging on Key Vault access                             | Not implemented       | Enable Key Vault diagnostic logs → Log Analytics                  |
| Rate limiting is per-API-key, not per-IP                         | By design             | A valid key can still abuse the service from many IPs             |
| Key Vault purge protection disabled                              | By design (demo ease) | **Must enable** `purge_protection_enabled = true` in production   |


## What's Missing for Production

- **Azure Front Door + WAF** with OWASP managed ruleset — proper edge protection and DDoS mitigation
- **DDoS Protection Standard** on the VNet
- **Key Vault purge protection** (`purge_protection_enabled = true`)
- **Secret rotation** — Key Vault + Event Grid trigger to rotate the `api-key` on a schedule
- **Private endpoint for Key Vault** — currently Key Vault allows selected public IPs; in production it should also move behind a private endpoint
- **NSG flow logs → Traffic Analytics** — visibility into network flows
- **Microsoft Defender for Cloud** enabled on all resource types
- **Azure Policy** for compliance enforcement (e.g. require TLS 1.2, deny public endpoint creation)

