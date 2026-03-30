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

variable "redis_resource_id" {
  description = "Resource ID of the Redis instance — required for private endpoint creation"
  type        = string
  default     = ""
}
