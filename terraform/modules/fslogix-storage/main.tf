# =============================================================================
# Module: fslogix-storage
# Description: Azure Files Premium for FSLogix profile containers
# =============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

# Premium storage account for FSLogix
resource "azurerm_storage_account" "fslogix" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Premium"
  account_replication_type = "LRS"
  account_kind             = "FileStorage"
  min_tls_version          = "TLS1_2"

  azure_files_authentication {
    directory_type = "AADKERB"
  }

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }

  tags = var.tags
}

# Profile share -- 100 GiB provisioned
resource "azurerm_storage_share" "profiles" {
  name                 = "profileshare"
  storage_account_name = azurerm_storage_account.fslogix.name
  quota                = 100  # GiB -- expand as user base grows
  enabled_protocol     = "SMB"
}

# Private endpoint for profile share -- keeps traffic on Azure private network
resource "azurerm_private_endpoint" "fslogix_files" {
  name                = "pe-fslogix-files"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-fslogix-files"
    private_connection_resource_id = azurerm_storage_account.fslogix.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  tags = var.tags
}

# Azure Backup protection for FSLogix profile share
resource "azurerm_backup_container_storage_account" "fslogix" {
  resource_group_name = var.resource_group_name
  recovery_vault_name = var.recovery_vault_name
  storage_account_id  = azurerm_storage_account.fslogix.id
}

resource "azurerm_backup_protected_file_share" "profiles" {
  resource_group_name       = var.resource_group_name
  recovery_vault_name       = var.recovery_vault_name
  source_storage_account_id = azurerm_storage_account.fslogix.id
  source_file_share_name    = azurerm_storage_share.profiles.name
  backup_policy_id          = var.backup_policy_id
}

output "storage_account_id" {
  value = azurerm_storage_account.fslogix.id
}

output "storage_account_name" {
  value = azurerm_storage_account.fslogix.name
}

output "profile_share_name" {
  value = azurerm_storage_share.profiles.name
}

output "profile_share_url" {
  value = "\\\\${azurerm_storage_account.fslogix.name}.file.core.windows.net\\profileshare"
}
