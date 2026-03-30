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

variable "owner_object_id" {
  description = "AAD object ID of the deploying user — granted Key Vault Secrets Officer"
  type        = string
}

variable "allowed_ip_cidrs" {
  description = "IP CIDRs allowed to reach Key Vault (e.g. your local IP)"
  type        = list(string)
}

variable "redis_hostname" {
  description = "Redis hostname stored as a Key Vault secret"
  type        = string
  default     = ""
}

variable "app_service_principal_id" {
  description = "Principal ID of the App Service managed identity — granted Key Vault Secrets User"
  type        = string
  default     = ""
}
