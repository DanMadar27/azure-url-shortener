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

variable "alert_email" {
  description = "Email address for alert notifications"
  type        = string
}

variable "app_service_id" {
  description = "Resource ID of the App Service — used for diagnostic settings and alert rules"
  type        = string
  default     = ""
}

variable "redis_id" {
  description = "Resource ID of the Redis instance — used for diagnostic settings"
  type        = string
  default     = ""
}
