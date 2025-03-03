# ------- Log Analytics & Sentinel Configuration -------

# Create Log Analytics Workspace -> To collect successful and failed RDP logins
resource "azurerm_log_analytics_workspace" "LogAnalytics" {
  name                = "${var.prefix}-LogAnalytics"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days = 30
  
}



# Install Azure Monitor Agent on Windows VM
resource "azurerm_virtual_machine_extension" "AMA" {
  name                       = "AzureMonitorWindowsAgent"
  virtual_machine_id         = azurerm_windows_virtual_machine.HP-WS1.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  depends_on = [ azurerm_windows_virtual_machine.HP-WS1 ]

  settings = <<SETTINGS
    {
      "authentication": {
        "managedIdentity": {
          "identifier-name": "mi_res_id",
          "identifier-value": "${azurerm_windows_virtual_machine.HP-WS1.id}"
        }
      }
    }
  SETTINGS

  tags = {
    environment = "SOC"
  }
}

# Add Windows Event Logs data source - HP VM Security Events
resource "azurerm_monitor_data_collection_rule" "HP-VM-Security-Events" {
  name                = "${var.prefix}-HP-VM-Security-Events"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  depends_on          = [azurerm_virtual_machine_extension.AMA]
  kind                = "Windows"

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.LogAnalytics.id
      name                  = "destination-la"
    }
  }
  
  data_flow {
    streams                 = ["Microsoft-Event"]
    destinations            = ["destination-la"]
  }

  data_sources {
    windows_event_log {
      name           = "security-events"
      streams        = ["Microsoft-Event"]
      x_path_queries = ["Security!*[System[(EventID=4624)]]"] # Successful login events
    }
    
    windows_event_log {
      name           = "rdp-events"
      streams        = ["Microsoft-Event"]
      x_path_queries = ["Security!*[System[(EventID=4624)] and EventData[Data[@Name='LogonType']='10']]"] # RDP logon type
    }
    
    windows_event_log {
      name           = "system-events"
      streams        = ["Microsoft-Event"]
      x_path_queries = ["System!*"]
    }
    
    windows_event_log {
      name           = "application-events"
      streams        = ["Microsoft-Event"]
      x_path_queries = ["Application!*"]
    }
  }
}

# Data Collection Rule Association
resource "azurerm_monitor_data_collection_rule_association" "hp_dcra" {
  name                    = "${var.prefix}-hp-dcra"
  target_resource_id      = azurerm_windows_virtual_machine.HP-WS1.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.HP-VM-Security-Events.id
  description             = "Association between honeypot VM and data collection rule"
  depends_on             = [azurerm_monitor_data_collection_rule.HP-VM-Security-Events]
}

# Onboard Log Analytics Workspace to Microsoft Sentinel
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "Sentinel" {
  workspace_id = azurerm_log_analytics_workspace.LogAnalytics.id
  customer_managed_key_enabled = false

  timeouts {
    create = "60m"
  }
}


# Create Sentinel Rule - Successful RDP Login - Win 10 HP VM 
resource "azurerm_sentinel_alert_rule_scheduled" "successful_rdp_login" {
 name                       = "${var.prefix}-SuccessfulRDPLogin-HP"
 log_analytics_workspace_id = azurerm_log_analytics_workspace.LogAnalytics.id
 display_name               = "Successful RDP Login"
 severity                   = "High"
 tactics                    = ["InitialAccess"] 
 query_frequency            = "PT5M"
 query_period               = "PT5M"
 query                      = <<QUERY
SecurityEvent
| where EventID == 4624
| project TimeGenerated, Account, Computer, IpAddress, LogonType
QUERY

  timeouts {
    create = "60m"
  }

 trigger_operator       = "GreaterThan"
 trigger_threshold      = 0
 description            = "Terraform - Alert on successful RDP login"
 suppression_enabled    = false

 incident {
   create_incident_enabled = true
   grouping {
      enabled                 = false
    }
  }

  entity_mapping {
    entity_type = "Account"
    field_mapping {
      identifier = "FullName"
      column_name = "Account"
    }
  }

  entity_mapping {
    entity_type = "Host"
    field_mapping {
      identifier = "FullName"
      column_name = "Computer"
    }
  }

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier = "Address"
      column_name = "IpAddress"
    }
  }

  depends_on = [
    azurerm_sentinel_log_analytics_workspace_onboarding.Sentinel
  ]
}

# Create Sentinel Rule - Failed RDP Login - Win 10 HP VM 
