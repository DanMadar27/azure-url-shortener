resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# ── Networking ──────────────────────────────────────────────────────────────
# First pass: VNet, subnets, NSGs, DNS zone — no private endpoint yet
module "networking" {
  source              = "./modules/networking"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tags                = local.common_tags
  redis_resource_id   = module.redis.redis_id
}

# ── ACR ─────────────────────────────────────────────────────────────────────
module "acr" {
  source                   = "./modules/acr"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  tags                     = local.common_tags
  app_service_principal_id = module.app_service.principal_id
}

# ── Key Vault ────────────────────────────────────────────────────────────────
module "key_vault" {
  source                   = "./modules/key_vault"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  tags                     = local.common_tags
  owner_object_id          = var.owner_object_id
  allowed_ip_cidrs         = var.allowed_ip_cidrs
  redis_hostname           = module.redis.hostname
  app_service_principal_id = module.app_service.principal_id
}

# ── Redis ────────────────────────────────────────────────────────────────────
module "redis" {
  source                   = "./modules/redis"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  tags                     = local.common_tags
  app_service_principal_id = module.app_service.principal_id
}

# ── Monitoring ───────────────────────────────────────────────────────────────
module "monitoring" {
  source              = "./modules/monitoring"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tags                = local.common_tags
  alert_email         = var.alert_email
  app_service_id      = module.app_service.app_service_id
  redis_id            = module.redis.redis_id
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
