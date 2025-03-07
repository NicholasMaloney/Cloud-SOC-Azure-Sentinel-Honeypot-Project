# I am working on a Cloud based Security operations center hosted in Azure. 
# I have already configured a virtual machine for MISP (Malware Information Sharing Platform) and now I need to create an Azure Function to collect data from MISP.
# I have created a resource group and a storage account for the Azure Function.
# I need to do the following: 
  # Create an Azure Function App Service Plan for the Azure Function
  # Create an Azure Function App for the Azure Function
  # Create a key vault to store the Azure Function App's secrets or I need to set them as Environment Variables 
  # I think I need to associate the storage account with the Azure Function App
  # Create application insights for the Azure Function & Connect it to the existing log analytics workspace

# Get current client config for tenant ID
data "azurerm_client_config" "current" {}

# ---------------

# Application registration for the Azure Function
resource "azuread_application" "MISP2Sentinel" {
  display_name = "${var.prefix}-MISP2Sentinel"
  owners       = [data.azuread_client_config.current.object_id, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"] 
  
  app_role {
    allowed_member_types = ["Application"]
    description          = "Reads data from MISP and sends it to Microsoft Sentinel"
    display_name         = "MISP2Sentinel"
    id                   = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    value                = "MISP2Sentinel"
    enabled              = true 
  }
}

# Create a Service Principal for the Application
resource "azuread_service_principal" "misp_sp" {
  client_id = azuread_application.MISP2Sentinel.client_id
  
}

# Create a client secret for the application
resource "azuread_application_password" "misp2sentinel_secret" {
  application_id = azuread_application.MISP2Sentinel.id
  display_name = "MISP2Sentinel-Secret"
}

# Assign Microsoft Sentinel Contributor role to the service principal
resource "azurerm_role_assignment" "Sentinel-Contributor" {
  principal_id = azuread_service_principal.misp_sp.object_id
  role_definition_name = "Microsoft Sentinel Contributor"
  scope = azurerm_log_analytics_workspace.LogAnalytics.id
  depends_on = [ azurerm_log_analytics_workspace.LogAnalytics ]
  
}

# App service plan for the Azure Function for MISP data
resource "azurerm_service_plan" "MISP-Service-Plan" {
    name                = "${var.prefix}-MISP-SP"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    os_type = "Linux"
    sku_name = "B1"
}

# Application Insights for the Azure Function
resource "azurerm_application_insights" "MISP-AppInsights" {
  name                = "${var.prefix}-MISP-AppInsights"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.LogAnalytics.id
  application_type    = "web"
}


# Azure Function for MISP data
resource "azurerm_linux_function_app" "MISP-Func" {
  resource_group_name        = azurerm_resource_group.rg.name
  name                       = "${var.prefix}-MISP-Func"
  location                   = azurerm_resource_group.rg.location
  service_plan_id            = azurerm_service_plan.MISP-Service-Plan.id
  storage_account_name       = azurerm_storage_account.misp-storage.name
  storage_account_access_key = azurerm_storage_account.misp-storage.primary_access_key
  
 site_config {
   always_on = true
   
   application_stack {
    python_version = "3.11"
   } 
 }
  # This should set the environment variables for the Azure Function / MISP 
 app_settings = {
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.MISP-AppInsights.instrumentation_key
    timerTriggerSchedule           = "0 */2 * * * "
    AzureFunctionsJobHost__functionTimeout = "02:00:00"
    mispurl                        = "${var.url}${azurerm_linux_virtual_machine.MISP-VM.public_ip_address}"
    client_id                      = azuread_application.MISP2Sentinel.client_id
    client_secret                  = azuread_application_password.misp2sentinel_secret.value
    tenant_id                      = var.tenant_id
    workspace_id                   = azurerm_log_analytics_workspace.LogAnalytics.workspace_id
    # Need to set the value of (mispkey) as an environment variable manually for the Azure Function
 }
}

# Storage account for the Azure Function for MISP data
resource "azurerm_storage_account" "misp-storage" {
    name                     = "mispstorage777"
    resource_group_name      = azurerm_resource_group.rg.name
    location                 = azurerm_resource_group.rg.location
    account_tier             = "Standard"
    account_replication_type = "LRS"
}
