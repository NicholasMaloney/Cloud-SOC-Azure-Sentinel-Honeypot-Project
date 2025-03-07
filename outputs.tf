# Retrieves information about your current Azure environment during Terraform execution




# Unique Instrumentation Key for the Azure Function used to send telemetry data (such as logs, metrics, and traces) from your application to Application Insights.
# After running terraform apply, the value of the instrumentation_key will be displayed in the terminal.
output "instrumentation_key" {
  value = azurerm_application_insights.MISP-AppInsights.instrumentation_key
  sensitive = true
}

# Unique identifier for Application Insights resource
# used to query telemetry data and interact with the Application Insights API
output "app_id" {
  value = azurerm_application_insights.MISP-AppInsights.app_id
  sensitive = false
}

# Output important values for the Function & App 
output "application_client_id" {
  value     = azuread_application.MISP2Sentinel.client_id
  sensitive = false
}

output "application_object_id" {
  value     = azuread_application.MISP2Sentinel.object_id
  sensitive = false
}

output "tenant_id" {
  value     = data.azurerm_client_config.current.tenant_id
  sensitive = false
}

output "client_secret" {
  value     = azuread_application_password.misp2sentinel_secret.value
  sensitive = true
}
