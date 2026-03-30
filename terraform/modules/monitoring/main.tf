resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-url-shortener"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "main" {
  name                = "appi-url-shortener"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = var.tags
}

# Action group for alert email notifications
resource "azurerm_monitor_action_group" "email" {
  name                = "ag-url-shortener-email"
  resource_group_name = var.resource_group_name
  short_name          = "urlshort"
  tags                = var.tags

  email_receiver {
    name                    = "primary"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

# Diagnostic settings for App Service
resource "azurerm_monitor_diagnostic_setting" "app_service" {
  count                      = var.app_service_id != "" ? 1 : 0
  name                       = "diag-app-service"
  target_resource_id         = var.app_service_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log { category = "AppServiceHTTPLogs" }
  enabled_log { category = "AppServiceConsoleLogs" }
  enabled_log { category = "AppServiceAppLogs" }
  enabled_log { category = "AppServicePlatformLogs" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Diagnostic settings for Redis
resource "azurerm_monitor_diagnostic_setting" "redis" {
  count                      = var.redis_id != "" ? 1 : 0
  name                       = "diag-redis"
  target_resource_id         = var.redis_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log { category = "ConnectedClientList" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Alert: HTTP 5xx > 5 in 5 minutes
resource "azurerm_monitor_metric_alert" "http_5xx" {
  count               = var.app_service_id != "" ? 1 : 0
  name                = "alert-http-5xx"
  resource_group_name = var.resource_group_name
  scopes              = [var.app_service_id]
  description         = "Fires when HTTP 5xx errors exceed 5 in a 5-minute window"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action {
    action_group_id = azurerm_monitor_action_group.email.id
  }
}

# Alert: health check status < 100 over 5 minutes
resource "azurerm_monitor_metric_alert" "health_check" {
  count               = var.app_service_id != "" ? 1 : 0
  name                = "alert-health-check"
  resource_group_name = var.resource_group_name
  scopes              = [var.app_service_id]
  description         = "Fires when App Service health check score drops below 100"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "HealthCheckStatus"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 100
  }

  action {
    action_group_id = azurerm_monitor_action_group.email.id
  }
}
