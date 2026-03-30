variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "West Europe"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-url-shortener-demo"
}

variable "allowed_ip_cidrs" {
  description = "List of IP CIDRs allowed to reach the App Service (e.g. your local IP)"
  type        = list(string)
}

variable "alert_email" {
  description = "Email address for monitoring alert notifications"
  type        = string
}

variable "owner_object_id" {
  description = "AAD object ID of the deploying user — granted Key Vault Secrets Officer role"
  type        = string
}

variable "owner_name" {
  description = "Owner name used in resource tags"
  type        = string
}

locals {
  common_tags = {
    environment = "demo"
    project     = "url-shortener"
    owner       = var.owner_name
  }
}
