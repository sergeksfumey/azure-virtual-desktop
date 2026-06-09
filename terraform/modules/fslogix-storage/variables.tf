variable "storage_account_name" {
  description = "Storage account name (globally unique)"
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "allowed_subnet_ids" {
  description = "Subnet IDs allowed to access FSLogix storage (session host subnets)"
  type        = list(string)
}

variable "private_endpoint_subnet_id" {
  type = string
}

variable "recovery_vault_name" {
  type = string
}

variable "backup_policy_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
