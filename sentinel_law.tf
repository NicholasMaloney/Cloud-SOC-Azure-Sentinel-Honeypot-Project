# ------- Log Analytics & Sentinel Configuration -------

# Create Log Analytics Workspace -> To collect successful and failed RDP logins
resource "azurerm_log_analytics_workspace" "LogAnalytics" {
  name                = "${var.prefix}-LogAnalytics"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
}

# Installing Log Analytics Agent on the Windows 10 Honey Pot VM
resource "azurerm_virtual_machine_extension" "log_Analytics_Agent" {
  name                       = "${var.prefix}-LogAnalyticsAgent"
  virtual_machine_id         = azurerm_windows_virtual_machine.HP-WS1.id
  publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
  type                       = "MicrosoftMonitoringAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true 

  settings = <<SETTINGS
    {
      "workspaceId": "${azurerm_log_analytics_workspace.LogAnalytics.workspace_id}"
    }
  SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
      "workspaceKey": "${azurerm_log_analytics_workspace.LogAnalytics.primary_shared_key}"
    }
  PROTECTED_SETTINGS
}

# Onboard Log Analytics Workspace to Microsoft Sentinel
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "Sentinel" {
  workspace_id = azurerm_log_analytics_workspace.LogAnalytics.id
  customer_managed_key_enabled = false

  timeouts {
    create = "60m"
  }
}

# Add Security Insights solution
resource "azurerm_log_analytics_solution" "SecurityInsights" {
  solution_name         = "SecurityInsights"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  workspace_resource_id = azurerm_log_analytics_workspace.LogAnalytics.id
  workspace_name       = azurerm_log_analytics_workspace.LogAnalytics.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/SecurityInsights"
  }
}


# Create Sentinel Rule - Successful RDP Login - Win 10 HP VM 
resource "azurerm_sentinel_alert_rule_scheduled" "successful_rdp_login" {
 name                       = "${var.prefix}-SuccessfulRDPLogin"
 log_analytics_workspace_id = azurerm_log_analytics_workspace.LogAnalytics.id
 display_name               = "Successful RDP Login"
 severity                   = "High"
 tactics                    = ["InitialAccess"] 
 query_frequency            = "PT5M"
 query_period               = "PT5M"
 query                      = <<QUERY
SecurityEvent | 
    where Activity contains "success" and Account !contains "system"
QUERY
  depends_on = [
    azurerm_sentinel_log_analytics_workspace_onboarding.Sentinel,
    azurerm_log_analytics_workspace.LogAnalytics
  ]

 trigger_operator       = "GreaterThan"
 trigger_threshold      = 0
 suppression_duration   = "PT5H"
 suppression_enabled    = true
 event_grouping {
   aggregation_method = "SingleAlert"
 }

}

# Create Sentinel Rule - Failed RDP Login - Win 10 HP VM 
resource "azurerm_sentinel_alert_rule_scheduled" "Failed_rdp_login" {
 name                       = "${var.prefix}-FailedRDPLogin"
 log_analytics_workspace_id = azurerm_log_analytics_workspace.LogAnalytics.id
 display_name               = "Failed RDP Login"
 severity                   = "Medium"
 tactics                    = ["CredentialAccess"] 
 query_frequency            = "PT5M"
 query_period               = "PT5M"
 query =                    <<QUERY
SecurityEvent
  | where EventID == 4625
  | summarize count() by TargetAccount, Computer, _ResourceID
QUERY
  depends_on = [
    azurerm_sentinel_log_analytics_workspace_onboarding.Sentinel,
    azurerm_log_analytics_workspace.LogAnalytics
 ]

  trigger_operator       = "GreaterThan"
  trigger_threshold      = 5  # Alert after 5 failed attempts
  suppression_duration   = "PT5H"
  suppression_enabled    = true
  event_grouping {
    aggregation_method = "SingleAlert"
  }
}