variable "resource_group_name" {
  type    = string
  default = "rg-avd-prod"
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "max_sessions_per_host" {
  type    = number
  default = 10
}

variable "initial_session_host_count" {
  type    = number
  default = 3
}

variable "session_host_vm_size" {
  type    = string
  default = "Standard_D4s_v5"
}

variable "avd_users_group_object_id" {
  description = "Entra ID group object ID for AVD users"
  type        = string
}

variable "admin_username" {
  type = string
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "gallery_image_id" {
  description = "Azure Compute Gallery image resource ID"
  type        = string
}

variable "fslogix_storage_account_name" {
  description = "Storage account name for FSLogix profiles (globally unique)"
  type        = string
}
