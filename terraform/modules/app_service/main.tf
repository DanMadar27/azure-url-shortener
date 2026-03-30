resource "azurerm_service_plan" "main" {
  name                = "asp-url-shortener"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "B2"
  tags                = var.tags
}

resource "azurerm_linux_web_app" "main" {
  name                = "app-url-shortener-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                         = true
    health_check_path                 = "/health"
    health_check_eviction_time_in_min = 10
    minimum_tls_version               = "1.2"

    application_stack {
      docker_image_name   = "${var.acr_login_server}/url-shortener:latest"
      docker_registry_url = "https://${var.acr_login_server}"
    }

    # Allow local IP(s) and the Azure health check probe IP
    dynamic "ip_restriction" {
      for_each = var.allowed_ip_cidrs
      content {
        ip_address = ip_restriction.value
        action     = "Allow"
        priority   = 100 + index(var.allowed_ip_cidrs, ip_restriction.value)
        name       = "allow-owner-ip-${index(var.allowed_ip_cidrs, ip_restriction.value)}"
      }
    }

    ip_restriction {
      ip_address = "168.63.129.16/32"
      action     = "Allow"
      priority   = 200
      name       = "allow-azure-health-check"
    }

    ip_restriction_default_action = "Deny"
  }

  app_settings = {
    REDIS_HOST                             = var.redis_hostname
    KEY_VAULT_URL                          = var.key_vault_url
    WEBSITES_PORT                          = "8000"
    WEBSITE_VNET_ROUTE_ALL                 = "1"
    APPLICATIONINSIGHTS_CONNECTION_STRING  = var.app_insights_connection_string
    WEBSITES_ENABLE_APP_SERVICE_STORAGE    = "false"
  }

  virtual_network_subnet_id = var.app_subnet_id
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# Autoscale: scale out at 70% CPU, scale in at 30% CPU
resource "azurerm_monitor_autoscale_setting" "main" {
  name                = "autoscale-url-shortener"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_service_plan.main.id
  tags                = var.tags

  profile {
    name = "default"

    capacity {
      default = 1
      minimum = 1
      maximum = 3
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }
    }
  }
}
