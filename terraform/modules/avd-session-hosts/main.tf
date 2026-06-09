# =============================================================================
# Module: avd-session-hosts
# Description: AVD session host VMs with Azure AD Join and Intune enrollment
# =============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

resource "azurerm_network_interface" "session_hosts" {
  count               = var.session_host_count
  name                = "nic-avd-sh-${count.index + 1}"
  resource_group_name = var.resource_group_name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

resource "azurerm_windows_virtual_machine" "session_hosts" {
  count               = var.session_host_count
  name                = "avd-sh-${count.index + 1}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  zone                = tostring((count.index % 3) + 1)  # Distribute across AZs

  network_interface_ids = [azurerm_network_interface.session_hosts[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_id = var.gallery_image_id

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Azure AD Join extension
resource "azurerm_virtual_machine_extension" "aad_join" {
  count                      = var.session_host_count
  name                       = "AADLoginForWindows"
  virtual_machine_id         = azurerm_windows_virtual_machine.session_hosts[count.index].id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    mdmId = "0000000a-0000-0000-c000-000000000000"  # Intune MDM app ID
  })
}

# AVD DSC extension for host pool join
resource "azurerm_virtual_machine_extension" "avd_dsc" {
  count                      = var.session_host_count
  name                       = "Microsoft.PowerShell.DSC"
  virtual_machine_id         = azurerm_windows_virtual_machine.session_hosts[count.index].id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true

  depends_on = [azurerm_virtual_machine_extension.aad_join]

  settings = jsonencode({
    modulesUrl            = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02714.342.zip"
    configurationFunction = "Configuration.ps1\AddSessionHost"
    properties = {
      HostPoolName          = var.host_pool_name
      RegistrationInfoToken = var.registration_token
      AadJoin               = true
      SessionHostConfigurationLastUpdateTime = ""
    }
  })
}

# Azure Monitor Agent
resource "azurerm_virtual_machine_extension" "ama" {
  count                      = var.session_host_count
  name                       = "AzureMonitorWindowsAgent"
  virtual_machine_id         = azurerm_windows_virtual_machine.session_hosts[count.index].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  depends_on = [azurerm_virtual_machine_extension.aad_join]
}

output "session_host_ids" {
  value = azurerm_windows_virtual_machine.session_hosts[*].id
}

output "session_host_names" {
  value = azurerm_windows_virtual_machine.session_hosts[*].name
}
