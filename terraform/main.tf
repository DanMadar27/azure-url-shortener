resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# ── Networking ──────────────────────────────────────────────────────────────
module "networking" {
  source              = "./modules/networking"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tags                = local.common_tags
}

# ── ACR ─────────────────────────────────────────────────────────────────────
module "acr" {
  source              = "./modules/acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tags                = local.common_tags
}

# ── Key Vault ────────────────────────────────────────────────────────────────
module "key_vault" {
  source              = "./modules/key_vault"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tags                = local.common_tags
  owner_object_id     = var.owner_object_id
  allowed_ip_cidrs    = var.allowed_ip_cidrs
}

# ── Redis ────────────────────────────────────────────────────────────────────
module "redis" {
  source              = "./modules/redis"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tags                = local.common_tags
}

# ── Monitoring ───────────────────────────────────────────────────────────────
module "monitoring" {
  source              = "./modules/monitoring"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tags                = local.common_tags
  alert_email         = var.alert_email
}

# ── App Service ───────────────────────────────────────────────────────────────
module "app_service" {
  source                         = "./modules/app_service"
  resource_group_name            = azurerm_resource_group.main.name
  location                       = var.location
  tags                           = local.common_tags
  app_subnet_id                  = module.networking.app_subnet_id
  acr_login_server               = module.acr.login_server
  redis_hostname                 = module.redis.hostname
  key_vault_url                  = module.key_vault.key_vault_url
  app_insights_connection_string = module.monitoring.app_insights_connection_string
  allowed_ip_cidrs               = var.allowed_ip_cidrs
}

# ── Cross-module role assignments ─────────────────────────────────────────────
resource "azurerm_role_assignment" "acr_pull" {
  scope                = module.acr.acr_id
  role_definition_name = "AcrPull"
  principal_id         = module.app_service.principal_id
}

resource "azurerm_role_assignment" "redis_contributor" {
  scope                = module.redis.redis_id
  role_definition_name = "Redis Cache Contributor"
  principal_id         = module.app_service.principal_id
}

# Data-plane access for Entra ID auth — Redis access policy, not Azure RBAC
resource "azurerm_redis_cache_access_policy_assignment" "app_service" {
  name               = "app-service-data-owner"
  redis_cache_id     = module.redis.redis_id
  access_policy_name = "Data Owner"
  object_id          = module.app_service.principal_id
  object_id_alias    = "app-service-identity"
}

resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = module.key_vault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.app_service.principal_id
}

# ── Key Vault secrets that depend on other modules ────────────────────────────
resource "azurerm_key_vault_secret" "redis_host" {
  name         = "redis-host"
  value        = module.redis.hostname
  key_vault_id = module.key_vault.key_vault_id

  depends_on = [module.key_vault]
}

# ── Private endpoint for Redis ────────────────────────────────────────────────
resource "azurerm_private_endpoint" "redis" {
  name                = "pe-redis"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = module.networking.redis_subnet_id
  tags                = local.common_tags

  private_service_connection {
    name                           = "redis-private-connection"
    private_connection_resource_id = module.redis.redis_id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "redis-dns-zone-group"
    private_dns_zone_ids = [module.networking.private_dns_zone_id]
  }
}

# ── Diagnostic settings ───────────────────────────────────────────────────────
resource "azurerm_monitor_diagnostic_setting" "app_service" {
  name                       = "diag-app-service"
  target_resource_id         = module.app_service.app_service_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  enabled_log { category = "AppServiceHTTPLogs" }
  enabled_log { category = "AppServiceConsoleLogs" }
  enabled_log { category = "AppServiceAppLogs" }
  enabled_log { category = "AppServicePlatformLogs" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "redis" {
  name                       = "diag-redis"
  target_resource_id         = module.redis.redis_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  enabled_log { category = "ConnectedClientList" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ── Metric alerts ─────────────────────────────────────────────────────────────
resource "azurerm_monitor_metric_alert" "http_5xx" {
  name                = "alert-http-5xx"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [module.app_service.app_service_id]
  description         = "Fires when HTTP 5xx errors exceed 5 in a 5-minute window"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT5M"
  tags                = local.common_tags

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action {
    action_group_id = module.monitoring.action_group_id
  }
}

resource "azurerm_monitor_metric_alert" "health_check" {
  name                = "alert-health-check"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [module.app_service.app_service_id]
  description         = "Fires when App Service health check score drops below 100"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT5M"
  tags                = local.common_tags

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "HealthCheckStatus"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 100
  }

  action {
    action_group_id = module.monitoring.action_group_id
  }
}
