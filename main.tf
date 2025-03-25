# Main deployment file with modules

# Modules
module "honeypot" {
  source = "./modules/honeypot"

  rg_name     = azurerm_resource_group.rg.name
  location    = azurerm_resource_group.rg.location
  prefix      = var.prefix
  HP-NIC-ID   = module.networking.HP-NIC-ID      # Reference ID to the honeypot VM NIC
  LaWrkSpc_id = module.log-analytics.LaWrkSpc_id # Log analytics workspace, workspace ID
}

module "log-analytics" {
  source = "./modules/log-analytics"

  HP-VM-ID   = module.honeypot.HP-VM-ID # Reference ID to the honeypot VM
  rg_name    = azurerm_resource_group.rg.name
  location   = azurerm_resource_group.rg.location
  prefix     = var.prefix
  AMA-HP-WS1 = module.honeypot.AMA-HP-WS1-ID # Reference to the AMA install on the honeypot VM
}

module "misp" {
  source = "./modules/misp"

  rg_name                    = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  prefix                     = var.prefix
  misp_url                   = var.misp_url
  LaWrkSpc_id                = module.log-analytics.LaWrkSpc_id # Log analytics workspace, workspace ID
  MISP-NIC-ID                = module.networking.MISP-NIC-ID    # Reference ID to the MISP VM NIC
  rg-id                      = azurerm_resource_group.rg.id     # Resource group ID
  log-analytics-workspace-id = module.log-analytics.log-analytics-workspace-id
}

module "networking" {
  source = "./modules/networking"

  rg_name  = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  prefix   = var.prefix

}

module "sentinel" {
  source = "./modules/sentinel"

  rg_name    = azurerm_resource_group.rg.name
  location   = azurerm_resource_group.rg.location
  prefix     = var.prefix
  law-onb-id = module.log-analytics.law-onb-id # Log analytics workspace onboarding workspace ID
  SenLaOb    = module.log-analytics.SenLaOb    # Sentinel onboarding workspace resource ID
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-Resources"
  location = "australiaeast"
}
