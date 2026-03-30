data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                        = "kv-url-short-${random_string.suffix.result}"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  enable_rbac_authorization   = true
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false # NOTE: must be true in production
  tags                        = var.tags

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    ip_rules                   = var.allowed_ip_cidrs
  }
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "random_uuid" "api_key" {}

resource "azurerm_key_vault_secret" "api_key" {
  name         = "api-key"
  value        = random_uuid.api_key.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.owner_officer]
}

# Grant the deploying user Secrets Officer so they can create/read secrets
resource "azurerm_role_assignment" "owner_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.owner_object_id
}
