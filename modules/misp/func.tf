# This might indicate how to activate the MISP2Sentinel connector 
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/function_app_connection

# Get current client config for tenant ID
data "azurerm_client_config" "current" {}

# Get current Azure AD client config
data "azuread_client_config" "current" {}

# Azure App registration for MISP2Sentinel
resource "azuread_application" "MISP2Sentinel" {
  display_name = "${var.prefix}-MISP2Sentinel"
  owners       = [data.azuread_client_config.current.object_id]
}

# Create a Service Principal for the Application
# Need to assign the Application.ReadWrite.OwnedBy role to the service principal via AZ CLI 
resource "azuread_service_principal" "MISP-sp" {
  client_id = azuread_application.MISP2Sentinel.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

# Create a client secret for the application
resource "azuread_application_password" "MISP2Sentinel-secret" {
  application_id = azuread_application.MISP2Sentinel.id
  display_name   = "MISP2Sentinel-Secret"
}

# Set Sentinel contributor for MISP2Sentinel in Log Analytics
resource "azurerm_role_assignment" "Sentinel-Contributor" {
  principal_id         = azuread_service_principal.MISP-sp.object_id
  role_definition_name = "Microsoft Sentinel Contributor"
  scope                = var.rg-id
  depends_on           = [var.LaWrkSpc_id]
}

# Create a Keyvault
/*
resource "azurerm_key_vault" "MISP-KV" {
  name                = "${var.prefix}-MISP-KV"
  resource_group_name = var.rg_name
  location            = var.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
}


# Store the client secret in the Key Vault
resource "azurerm_key_vault_secret" "MISP-Client-Secret" {
  name         = "misp-client-secret"
  value        = azuread_application_password.MISP2Sentinel-secret.value
  key_vault_id = azurerm_key_vault.MISP-KV.id
}
*/

# App service plan for the Azure Function for MISP data
resource "azurerm_service_plan" "MISP-Service-Plan" {
  name                = "${var.prefix}-MISP-SP"
  location            = var.location
  resource_group_name = var.rg_name
  os_type             = "Linux"
  sku_name            = "B1"

  lifecycle {
    create_before_destroy = true
  }

  timeouts {
    create = "30m"
  }
}

# Application Insights for the Azure Function
resource "azurerm_application_insights" "MISP-AppInsights" {
  name                = "${var.prefix}-MISP-AppInsights"
  location            = var.location
  resource_group_name = var.rg_name
  workspace_id        = var.log-analytics-workspace-id
  application_type    = "other"
}

# Azure Function for MISP data
resource "azurerm_linux_function_app" "MISP-Func" {
  name                       = "${var.prefix}-MISP-Func"
  location                   = var.location
  resource_group_name        = var.rg_name
  service_plan_id            = azurerm_service_plan.MISP-Service-Plan.id
  storage_account_name       = azurerm_storage_account.misp_storage.name
  storage_account_access_key = azurerm_storage_account.misp_storage.primary_access_key
  depends_on                 = [azurerm_service_plan.MISP-Service-Plan, azurerm_storage_account.misp_storage]

  site_config {
    always_on                              = true
    application_insights_key               = azurerm_application_insights.MISP-AppInsights.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.MISP-AppInsights.connection_string

    application_stack {
      python_version = "3.9"
    }

    ip_restriction {
      action      = "Allow"
      service_tag = "AzureCloud"
    }
    # CORS configuration
    cors {
      allowed_origins = [
        "https://portal.azure.com",
        "https://functions.azure.com",
        "https://functions-staging.azure.com",
        "https://functions-next.azure.com"
      ]
      support_credentials = true
    }
  }
  app_settings = {
    SCM_DO_BUILD_DURING_DEPLOYMENT         = "true"
    APPINSIGHTS_INSTRUMENTATIONKEY         = "${azurerm_application_insights.MISP-AppInsights.instrumentation_key}"
    APPLICATIONINSIGHTS_CONNECTION_STRING  = "${azurerm_application_insights.MISP-AppInsights.connection_string}"
    timerTriggerSchedule                   = "0 */2 * * *"
    AzureFunctionsJobHost__functionTimeout = "02:00:00" # change to 00:10:00 if this didn't work
    mispurl                                = "${var.misp_url}${azurerm_linux_virtual_machine.MISP-VM.public_ip_address}"
    client_id                              = azuread_application.MISP2Sentinel.client_id
    client_secret                          = azuread_application_password.MISP2Sentinel-secret.value
    tenant_id                              = data.azurerm_client_config.current.tenant_id
    workspace_id                           = var.LaWrkSpc_id
    # Need to set the value of (mispkey) as an environment variable manually for the Azure Function
  }
}

# Storage account for the Azure Function for MISP data
resource "azurerm_storage_account" "misp_storage" {
  name                     = "cloudsocmispstorage"
  resource_group_name      = var.rg_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


