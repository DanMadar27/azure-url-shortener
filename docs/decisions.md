# Design Decisions

## Why a URL Shortener?

A URL shortener is a clean, self-contained scope that naturally exercises every platform engineering concern in this stack: Redis as a private backend with Entra ID auth, Key Vault for secret management, rate limiting as an inherent product requirement, health checks with meaningful degraded states, and a live demo possible in the review session. It avoids artificial complexity while demonstrating real production patterns.

## Why Redis Over SQL?

Redis provides native TTL support (URLs expire automatically at 30 days with no background job required), O(1) key lookups by short code, and built-in atomic increment for click counting and rate-limit sliding windows. A SQL database would require schema migrations, a background expiry job, and slower indexed lookups — more operational surface area for an access pattern that is fundamentally key-value.

## Why Managed Identity Over Service Principals?

Managed identity eliminates the credential lifecycle problem: no client secret to generate, rotate, store securely, or accidentally leak. Azure handles token issuance and rotation transparently. It works natively with Key Vault RBAC, Redis Entra ID auth, and ACR pull — the three integration points in this stack.

## Why X-API-Key Over OAuth2 / JWT

The API uses a single shared secret passed as an `X-API-Key` header. This was chosen because the demo has a single known consumer (the reviewer), no multi-tenant identity requirements, and no need for token expiry or refresh logic that would complicate a live walkthrough. The key is never hardcoded — Terraform generates a random UUID, stores it in Key Vault, and the application fetches it at startup via managed identity — so it remains credential-safe despite being a simple pattern.

OAuth2 client credentials flow is the documented production upgrade path: once there are multiple consumers who need independent keys, scopes, or revocation, a shared secret no longer scales.

## Key Assumptions and Tradeoffs

| Assumption / Tradeoff | Decision | Production alternative |
|---|---|---|
| Single consumer, known static IP | IP allowlist at App Service level | Azure Front Door + WAF for proper edge filtering and DDoS protection |
| Demo load — no sustained traffic | Redis Basic C1 (no clustering, no persistence) | Redis Premium with clustering and AOF persistence |
| One shared API key is acceptable | Single `api-key` secret in Key Vault | Per-consumer keys with independent revocation; OAuth2 client credentials |
| API key can be cached in memory for process lifetime | Fetch once at startup, cache forever | Short TTL cache with background refresh; listen for Key Vault events to invalidate |
| Purge protection adds friction during iterative demo teardown | `purge_protection_enabled = false` | Must be `true` in production — accidental deletion of Key Vault is unrecoverable without it |
| Key Vault does not need a private endpoint for demo scope | Key Vault allows selected public IPs | Key Vault behind a private endpoint, accessible only from the VNet |
| 30-day URL TTL is a reasonable default | Hardcoded in application config | Configurable per-URL TTL passed at creation time |

## Alternative Considered: Azure Front Door + WAF

Azure Front Door with a WAF policy would provide proper IP restriction at the edge (not at App Service level), DDoS protection, SSL offload, and OWASP managed rule sets. It was rejected for this demo because it adds provisioning complexity, cost, and a longer feedback loop — none of which are justified for a demo deployment with a single allowed IP. The current IP restriction at the App Service level is functionally equivalent for this scope.

Front Door + WAF is documented as the mandatory production upgrade in `security.md`.
