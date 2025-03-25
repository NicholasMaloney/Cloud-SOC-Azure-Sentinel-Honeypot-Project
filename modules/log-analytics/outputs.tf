output "LaWrkSpc_id" {
  value = azurerm_log_analytics_workspace.LogAnalytics.workspace_id

}

output "law-onb-id" {
  value = azurerm_sentinel_log_analytics_workspace_onboarding.Sentinel.workspace_id

}

output "SenLaOb" {
  value = azurerm_sentinel_log_analytics_workspace_onboarding.Sentinel

}

output "log-analytics-workspace-id" {
  value = azurerm_log_analytics_workspace.LogAnalytics.id

}
