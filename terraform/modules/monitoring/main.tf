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
