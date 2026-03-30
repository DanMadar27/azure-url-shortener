# Troubleshooting Guide

## Issue 1: HTTP 500 Errors (Intermittent)

### Step 1 — Identify the scope

Open **Application Insights → Failures** blade. Filter by HTTP status 500. Check whether failures are correlated with a specific App Service instance (available in the instance telemetry dimension).

### Step 2 — Query HTTP logs

```kql
AppServiceHTTPLogs
| where ScStatus == 500
| project TimeGenerated, CsUriStem, TimeTaken, CIp
| order by TimeGenerated desc
| take 50
```

Look for patterns: specific endpoints, specific source IPs, or time clustering.

### Step 3 — Query application exceptions

```kql
AppServiceConsoleLogs
| where ResultDescription contains "Error" or ResultDescription contains "Exception"
| order by TimeGenerated desc
| take 50
```

Stack traces appear here when FastAPI/uvicorn logs to stdout (which flows to `AppServiceConsoleLogs`).

### Step 4 — Investigate likely causes

| Symptom | Likely cause | Investigation |
|---------|-------------|---------------|
| Errors spike after restart | Redis connection not yet established | Check startup logs for connection errors |
| Errors on Redis-dependent endpoints only | Redis connection pool exhausted | Check Redis metric `connectedclients` in Azure Portal |
| Errors on all endpoints after some hours | Entra ID token refresh failure | App Insights → Dependencies → filter on `login.microsoftonline.com` |
| Errors on first request after idle | Key Vault throttling at startup | App Insights → Dependencies → filter on `vault.azure.net`, look for 429 |
| Unhandled exception | Application bug | Read full stack trace from `AppServiceConsoleLogs` |

### Step 5 — End-to-end trace

In Application Insights → Failures, click an individual failed request to see the full end-to-end transaction trace including all dependency calls (Key Vault, Redis, Entra ID token endpoint).

---

## Issue 2: API Reachable But Fails to Connect to Redis Backend

Work through the layers: DNS → network → auth → application.

### Step 1 — Verify DNS resolution

Open **App Service → Advanced Tools (Kudu) → SSH or Debug Console** and run:

```bash
nslookup <redis-name>.redis.cache.windows.net
```

**Expected result:** resolves to a private IP in the `10.0.2.x` range.

**If it resolves to a public IP:** the Private DNS Zone is not linked to the VNet. Go to Azure Portal → Private DNS Zones → `privatelink.redis.cache.windows.net` → Virtual network links → verify the VNet link exists and is `Registered`.

### Step 2 — Verify VNet Integration

App Service → **Networking → Outbound traffic → VNet integration**. The `app-subnet` (`10.0.1.0/24`) should appear as the integrated subnet. If not, re-enable VNet integration and confirm `WEBSITE_VNET_ROUTE_ALL=1` is set in app settings.

### Step 3 — Verify NSG rules

Navigate to `nsg-redis-subnet` in Azure Portal → Inbound security rules. Confirm:

- Priority 100: Allow TCP 6380 from source `10.0.1.0/24`
- Priority 4096: Deny All

If the allow rule is missing or the source CIDR is wrong, the connection will be refused at the network layer.

### Step 4 — Verify the private endpoint

Navigate to the private endpoint `pe-redis` → confirm its **Connection state** is `Approved` and its NIC IP is in `10.0.2.0/24`.

### Step 5 — Verify Entra ID role assignments

The App Service managed identity must have **Redis Data Owner** on the Redis resource. Role assignment propagation can take 5–10 minutes after `terraform apply`.

```bash
az role assignment list --scope <redis-resource-id> --query "[].{role:roleDefinitionName,principal:principalName}"
```

Also confirm Redis Entra ID authentication is enabled: Azure Portal → Redis → **Authentication** → Microsoft Entra ID Authentication should show **Enabled**.

### Step 6 — Check App Insights dependencies

Filter Application Insights → **Performance → Dependencies** for calls to the Redis hostname. Check latency and error codes:

| Observation | Conclusion |
|-------------|------------|
| DNS resolves to public IP | Private DNS Zone misconfiguration |
| DNS resolves correctly but connection times out | NSG blocking or private endpoint misconfigured |
| Connection established, auth error | Entra ID role assignment not propagated |
| Connection established, auth ok, wrong data | Application logic bug |
