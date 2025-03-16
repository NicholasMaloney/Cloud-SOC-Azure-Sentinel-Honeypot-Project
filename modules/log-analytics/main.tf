# Log analytics Workspace
resource "azurerm_log_analytics_workspace" "LogAnalytics" {
  name                = "${var.prefix}-LogAnalytics"
  location            = var.location
  resource_group_name = var.rg_name
  sku                 = "PerGB2018"
  retention_in_days   = 30

}

# Log Analytics Workspace -> Sentinel onboarding
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "Sentinel" {
  workspace_id = azurerm_log_analytics_workspace.LogAnalytics.id
  depends_on   = [azurerm_log_analytics_workspace.LogAnalytics]
}

# Honeypot Data collection rule
resource "azurerm_monitor_data_collection_rule" "HP-DCR" {
  name                = "${var.prefix}-HP-DCR"
  resource_group_name = var.rg_name
  location            = var.location
  depends_on          = [azurerm_virtual_machine_extension.AMA-HP-WS1]
  kind                = "Windows"

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.LogAnalytics.id
      name                  = "destination-law"
    }
  }

  data_flow {
    streams      = ["Microsoft-SecurityEvent"]
    destinations = ["destination-law"]
  }

  data_sources {
    windows_event_log {
      name           = "successful-login-events"
      streams        = ["Microsoft-SecurityEvent"]
      x_path_queries = ["Security!*[System[(EventID=4624)]]"] # Successful login events
    }

    windows_event_log {
      name           = "rdp-events"
      streams        = ["Microsoft-SecurityEvent"]
      x_path_queries = ["Security!*[System[(EventID=4624)] and EventData[Data[@Name='LogonType']='10']]"] # Successful RDP logon type
    }
  }
}

#  Honeypot Data collection rule association
resource "azurerm_monitor_data_collection_rule_association" "HP-DCRA" {
  name                    = "${var.prefix}-HP-DCRA"
  target_resource_id      = var.HP-VM-ID
  data_collection_rule_id = azurerm_monitor_data_collection_rule.HP-DCR.id
  description             = "Association between honeypot VM and data collection rule"
  depends_on              = [azurerm_monitor_data_collection_rule.HP-DCR]
}
