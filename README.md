# Azure URL Shortener

A production-grade URL shortener demonstrating Azure DevOps and platform engineering best practices. The application runs as a FastAPI Docker container on Azure App Service, stores URLs in Azure Cache for Redis, and retrieves secrets from Azure Key Vault — all authenticated via managed identity with no static credentials anywhere in the stack.

All sensitive data paths are protected: Redis has no public endpoint and is reachable only via a private endpoint inside the VNet. The API key is a randomly generated UUID stored exclusively in Key Vault. App Service inbound access is restricted to a configurable IP allowlist. All communication uses TLS 1.2 minimum.

The deployment is fully observable: Application Insights captures distributed traces and dependency calls (Key Vault, Redis, Entra ID), Log Analytics retains HTTP logs and application logs for 30 days, and metric alerts fire on HTTP 5xx spikes and health check degradation. Auto-scaling is configured to add instances when CPU exceeds 70% and remove them when it drops below 30%.

---

## Architecture

```
User → [HTTPS + X-API-Key] → App Service (FastAPI Docker)
                                  ↓ Managed Identity
                              Key Vault (api-key secret)
                                  ↓ Entra ID token, TLS 6380
                              Redis (private endpoint, no public access)
                                  ↓ Pull image
                              Azure Container Registry
                                  ↓ Logs + metrics
                              Application Insights → Log Analytics
```

See [docs/architecture.md](docs/architecture.md) for the full Mermaid diagram and detailed data flow.

---

## Prerequisites

- Azure CLI installed and authenticated (`az login`)
- Terraform >= 1.5
- Docker installed and running
- Azure subscription with **Owner** or **Contributor + User Access Administrator** roles
- Your local IP address (needed to configure IP restrictions and Key Vault network ACLs)
- Your AAD object ID: `az ad signed-in-user show --query id -o tsv`
- A Storage Account for Terraform remote state (see below)

### Terraform Remote State Setup

Terraform state is stored in Azure Blob Storage. Create the backend resources once before your first `terraform init`:

```bash
# Create a dedicated resource group for state
az group create --name rg-terraform-state --location westeurope

# Create the Storage Account (name must be globally unique — change if taken)
az storage account create \
  --name sttfstateurlshort \
  --resource-group rg-terraform-state \
  --sku Standard_LRS \
  --allow-blob-public-access false

# Create the blob container
az storage container create \
  --name tfstate \
  --account-name sttfstateurlshort \
  --auth-mode login
```

State locking is handled automatically via blob lease — no extra configuration needed. The Storage Account costs less than $0.01/month at this state file size.

---
## Azure CLI

Login to your account:

```bash
az login
```

See current profile:

```bash
az account show
```

Change chosen subscription ID:

```bash
az account set --subscription "35akss-subscription-id"
```

---

## Deployment

### 1. Clone and configure

```bash
git clone <repo>
cd azure-url-shortener/terraform

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set allowed_ip_cidrs, alert_email, owner_object_id, owner_name
```

### 2. Deploy infrastructure

```bash
terraform init
terraform apply
```

> **Note:** Terraform state is stored locally for this demo. For production, use an Azure Storage backend with state locking — see the commented-out `backend "azurerm"` block in `providers.tf`.

### 3. Build and push the Docker image

```bash
ACR_NAME=$(terraform output -raw acr_login_server)
az acr login --name $ACR_NAME

docker build -t $ACR_NAME/url-shortener:latest ../app
docker push $ACR_NAME/url-shortener:latest
```

### 4. Restart App Service to pull the new image

```bash
APP_NAME=$(terraform output -raw app_service_name)
az webapp restart --name $APP_NAME --resource-group rg-url-shortener-demo
```

### 5. Retrieve the API key

```bash
KV_NAME=$(terraform output -raw key_vault_name)
az keyvault secret show --vault-name $KV_NAME --name api-key --query value -o tsv
```

---

## UI

A web interface is available at the root URL:

```
https://<app-service-hostname>/
```

It supports shortening URLs, looking up short codes, and copying results — no curl required.

---

## Testing

```bash
APP_HOST=$(terraform output -raw app_service_hostname)
API_KEY="<api-key from step 5>"

# Shorten a URL
curl -X POST https://$APP_HOST/api/shorten \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.google.com"}'

# Optionally use a custom code
curl -X POST https://$APP_HOST/api/shorten \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.google.com", "custom_code": "google"}'

# Follow a short link (browser redirect)
curl -L https://$APP_HOST/r/<short_code>

# Get stats for a short code
curl https://$APP_HOST/api/stats/<short_code> \
  -H "X-API-Key: $API_KEY"

# Resolve a short code without redirect
curl https://$APP_HOST/api/redirect/<short_code> \
  -H "X-API-Key: $API_KEY"

# Health check (no auth required)
curl https://$APP_HOST/health
```

---

## Log Analytics

To access logs via the Azure Portal:

1. Go to [portal.azure.com](https://portal.azure.com)
2. Search for **Log Analytics workspaces**
3. Click `law-url-shortener`
4. Click **Logs** in the left sidebar

## Useful Log Analytics Queries

```kql
// Recent HTTP errors
AppServiceHTTPLogs
| where ScStatus >= 400
| project TimeGenerated, ScStatus, CsUriStem, TimeTaken
| order by TimeGenerated desc
| take 50

// Application exceptions
AppServiceConsoleLogs
| where ResultDescription contains "Exception" or ResultDescription contains "Error"
| order by TimeGenerated desc
| take 50

// Redis connectivity issues
AppServiceConsoleLogs
| where ResultDescription contains "redis" or ResultDescription contains "Redis"
| order by TimeGenerated desc
| take 50

// HTTP 500s with request timing
AppServiceHTTPLogs
| where ScStatus == 500
| project TimeGenerated, CsUriStem, TimeTaken, CIp
| order by TimeGenerated desc
```

---

## Documentation

| Document | Contents |
|----------|----------|
| [docs/architecture.md](docs/architecture.md) | Mermaid diagram, component overview, data flow, auth flows, network isolation |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Step-by-step guides for HTTP 500s and Redis connectivity issues |
| [docs/security.md](docs/security.md) | Secrets management, network controls, known risks, production hardening checklist |
| [docs/decisions.md](docs/decisions.md) | Design rationale and alternatives considered |
