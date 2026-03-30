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

variable "app_subnet_id" {
  description = "Subnet ID of the App Service VNet integration subnet — allowed through Key Vault firewall"
  type        = string
}

