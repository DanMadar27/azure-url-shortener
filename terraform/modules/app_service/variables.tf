variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "app_subnet_id" {
  description = "Subnet ID for VNet integration"
  type        = string
}

variable "acr_login_server" {
  description = "ACR login server URL (e.g. acr*.azurecr.io)"
  type        = string
}

variable "redis_hostname" {
  description = "Redis hostname passed as app setting"
  type        = string
}

variable "key_vault_url" {
  description = "Key Vault URL passed as app setting"
  type        = string
}

variable "app_insights_connection_string" {
  description = "Application Insights connection string"
  type        = string
  sensitive   = true
}

variable "allowed_ip_cidrs" {
  description = "List of IP CIDRs allowed to access App Service"
  type        = list(string)
}
