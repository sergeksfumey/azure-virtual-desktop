# =============================================================================
# Environment: Production
# Description: Azure Virtual Desktop for Hybrid Workforce
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-tfstate-prod"
    storage_account_name = "stgtfstateprod001"
    container_name       = "tfstate"
    key                  = "avd/prod.tfstate"
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-avd-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = local.tags
}

# VNet for AVD session hosts
resource "azurerm_virtual_network" "avd" {
  name                = "vnet-avd-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  address_space       = ["10.30.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "session_hosts" {
  name                 = "snet-avd-session-hosts"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.avd.name
  address_prefixes     = ["10.30.1.0/24"]
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.avd.name
  address_prefixes     = ["10.30.2.0/24"]
}

# NSG for session host subnet
resource "azurerm_network_security_group" "session_hosts" {
  name                = "nsg-avd-session-hosts"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  security_rule {
    name                       = "Allow-AVD-Control-Plane"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "WindowsVirtualDesktop"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.tags
}

resource "azurerm_subnet_network_security_group_association" "session_hosts" {
  subnet_id                 = azurerm_subnet.session_hosts.id
  network_security_group_id = azurerm_network_security_group.session_hosts.id
}

module "avd_host_pool" {
  source                     = "../../modules/avd-host-pool"
  host_pool_name             = "avd-hostpool"
  workspace_name             = "avd-workspace-prod"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.location
  max_sessions_per_host      = var.max_sessions_per_host
  avd_users_group_object_id  = var.avd_users_group_object_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  tags                       = local.tags
}

module "avd_session_hosts" {
  source             = "../../modules/avd-session-hosts"
  session_host_count = var.initial_session_host_count
  resource_group_name = azurerm_resource_group.main.name
  location           = var.location
  vm_size            = var.session_host_vm_size
  subnet_id          = azurerm_subnet.session_hosts.id
  admin_username     = var.admin_username
  admin_password     = var.admin_password
  gallery_image_id   = var.gallery_image_id
  host_pool_name     = module.avd_host_pool.host_pool_name
  registration_token = module.avd_host_pool.registration_token
  tags               = local.tags
}

resource "azurerm_recovery_services_vault" "avd" {
  name                = "rsv-avd-profiles-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "Standard"
  soft_delete_enabled = true
  tags                = local.tags
}

resource "azurerm_backup_policy_file_share" "profiles" {
  name                = "policy-profiles-daily"
  resource_group_name = azurerm_resource_group.main.name
  recovery_vault_name = azurerm_recovery_services_vault.avd.name

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 30
  }
}

module "fslogix_storage" {
  source                     = "../../modules/fslogix-storage"
  storage_account_name       = var.fslogix_storage_account_name
  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.location
  allowed_subnet_ids         = [azurerm_subnet.session_hosts.id]
  private_endpoint_subnet_id = azurerm_subnet.private_endpoints.id
  recovery_vault_name        = azurerm_recovery_services_vault.avd.name
  backup_policy_id           = azurerm_backup_policy_file_share.profiles.id
  tags                       = local.tags
}

locals {
  tags = {
    environment = "prod"
    project     = "avd-hybrid-workforce"
    owner       = "euc-team"
  }
}
