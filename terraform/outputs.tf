output "acr_login_server" {
  description = "ACR login server — use this to tag and push Docker images"
  value       = module.acr.login_server
}

output "app_service_name" {
  description = "App Service name — use with az webapp restart"
  value       = module.app_service.app_service_name
}

output "app_service_hostname" {
  description = "Public hostname of the App Service"
  value       = module.app_service.app_service_hostname
}

output "key_vault_name" {
  description = "Key Vault name — use to retrieve the api-key secret"
  value       = module.key_vault.key_vault_name
}
