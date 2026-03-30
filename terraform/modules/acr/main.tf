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
