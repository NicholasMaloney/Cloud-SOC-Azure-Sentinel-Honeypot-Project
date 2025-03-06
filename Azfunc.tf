# App service plan for the Azure Function for MISP data
resource "azurerm_service_plan" "MISP-Service-Plan" {
    name                = "${var.prefix}-MISP-SP"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    os_type = "Linux"
    sku_name = "B1"
}

# Storage account for the Azure Function for MISP data
resource "azurerm_storage_account" "misp-storage" {
    name                     = "mispstorage777"
    resource_group_name      = azurerm_resource_group.rg.name
    location                 = azurerm_resource_group.rg.location
    account_tier             = "Standard"
    account_replication_type = "LRS"
}

# Azure Function for MISP data
resource "azurerm_linux_function_app" "MISP-Func" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${var.prefix}-MISP-Func"
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.MISP-Service-Plan.id
  storage_account_name = azurerm_storage_account.misp-storage.name
  
 site_config {
   
   always_on = true
   
   application_stack {
     python_version = "3.11"
   }
   
 }

  
}