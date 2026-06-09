variable "session_host_count" {
  description = "Number of session host VMs to deploy"
  type        = number
  default     = 3
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vm_size" {
  description = "Session host VM SKU"
  type        = string
  default     = "Standard_D4s_v5"
}

variable "subnet_id" {
  type = string
}

variable "admin_username" {
  type = string
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "gallery_image_id" {
  description = "Azure Compute Gallery image ID for session hosts"
  type        = string
}

variable "host_pool_name" {
  type = string
}

variable "registration_token" {
  type      = string
  sensitive = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
