# =============================================================================
# Module: avd-host-pool
# Description: Azure Virtual Desktop host pool, workspace, and application group
# =============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

resource "azurerm_virtual_desktop_host_pool" "main" {
  name                     = var.host_pool_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  type                     = "Pooled"
  load_balancer_type       = "BreadthFirst"
  maximum_sessions_allowed = var.max_sessions_per_host
  validate_environment     = false

  scheduled_agent_updates {
    enabled  = true
    timezone = "UTC"
    schedule {
      day_of_week = "Sunday"
      hour_of_day = 2
    }
  }

  tags = var.tags
}

# Registration info for session host join
resource "azurerm_virtual_desktop_host_pool_registration_info" "main" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.main.id
  expiration_date = timeadd(timestamp(), "48h")
}

# Desktop application group
resource "azurerm_virtual_desktop_application_group" "desktop" {
  name                = "${var.host_pool_name}-dag"
  resource_group_name = var.resource_group_name
  location            = var.location
  host_pool_id        = azurerm_virtual_desktop_host_pool.main.id
  type                = "Desktop"
  tags                = var.tags
}

# Workspace
resource "azurerm_virtual_desktop_workspace" "main" {
  name                = var.workspace_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Associate application group with workspace
resource "azurerm_virtual_desktop_workspace_application_group_association" "main" {
  workspace_id         = azurerm_virtual_desktop_workspace.main.id
  application_group_id = azurerm_virtual_desktop_application_group.desktop.id
}

# Assign users to desktop application group
resource "azurerm_role_assignment" "avd_users" {
  scope                = azurerm_virtual_desktop_application_group.desktop.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = var.avd_users_group_object_id
}

# Diagnostic settings
resource "azurerm_monitor_diagnostic_setting" "host_pool" {
  name                       = "diag-avd-hostpool"
  target_resource_id         = azurerm_virtual_desktop_host_pool.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "Checkpoint" }
  enabled_log { category = "Error" }
  enabled_log { category = "Management" }
  enabled_log { category = "Connection" }
  enabled_log { category = "HostRegistration" }
  enabled_log { category = "AgentHealthStatus" }
}

output "host_pool_id" {
  value = azurerm_virtual_desktop_host_pool.main.id
}

output "host_pool_name" {
  value = azurerm_virtual_desktop_host_pool.main.name
}

output "registration_token" {
  value     = azurerm_virtual_desktop_host_pool_registration_info.main.token
  sensitive = true
}

output "app_group_id" {
  value = azurerm_virtual_desktop_application_group.desktop.id
}

output "workspace_id" {
  value = azurerm_virtual_desktop_workspace.main.id
}
