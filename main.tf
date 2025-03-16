# Main deployment file with modules

# Modules
module "honeypot" {
  source = "./modules/honeypot"

  rg_name  = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  prefix   = var.prefix
}

module "log-analytics" {
  source = "./modules/log-analytics"

  HP-VM-ID = module.honeypot.HP-VM.id
  rg_name  = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  prefix   = var.prefix
}

module "misp" {
  source = "./modules/misp"

  rg_name  = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  prefix   = var.prefix
}

module "networking" {
  source = "./modules/networking"

  rg_name  = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  prefix   = var.prefix

}

module "sentinel" {
  source = "./modules/sentinel"
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-Resources"
  location = "australiaeast"
}
