resource "azurerm_redis_cache" "main" {
  name                          = "redis-url-shortener-${random_string.suffix.result}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  capacity                      = 1
  family                        = "C"
  sku_name                      = "Basic"
  public_network_access_enabled = false
  minimum_tls_version           = "1.2"
  tags                          = var.tags

  redis_configuration {
    enable_authentication                    = true
    active_directory_authentication_enabled = true
  }
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}
