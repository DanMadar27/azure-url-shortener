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

variable "app_service_principal_id" {
  description = "Principal ID of the App Service managed identity — granted Redis Data Owner"
  type        = string
  default     = ""
}
