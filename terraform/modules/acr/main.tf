resource "azurerm_container_registry" "main" {
  name                = "acrurlshortener${random_string.suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = var.tags
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# AcrPull role for App Service managed identity — assigned after App Service is created
resource "azurerm_role_assignment" "acr_pull" {
  count                = var.app_service_principal_id != "" ? 1 : 0
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = var.app_service_principal_id
}
