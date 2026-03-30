output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "app_subnet_id" {
  value = azurerm_subnet.app.id
}

output "redis_subnet_id" {
  value = azurerm_subnet.redis.id
}

output "private_dns_zone_id" {
  value = azurerm_private_dns_zone.redis.id
}
