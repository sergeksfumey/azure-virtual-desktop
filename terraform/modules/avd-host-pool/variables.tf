variable "host_pool_name" {
  type = string
}

variable "workspace_name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "max_sessions_per_host" {
  description = "Maximum concurrent sessions per session host VM"
  type        = number
  default     = 10
}

variable "avd_users_group_object_id" {
  description = "Entra ID group object ID for AVD users"
  type        = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
