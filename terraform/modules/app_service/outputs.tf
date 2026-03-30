output "app_service_id" {
  value = azurerm_linux_web_app.main.id
}

output "app_service_name" {
  value = azurerm_linux_web_app.main.name
}

output "app_service_hostname" {
  value = azurerm_linux_web_app.main.default_hostname
}

output "principal_id" {
  description = "System-assigned managed identity principal ID"
  value       = azurerm_linux_web_app.main.identity[0].principal_id
}
