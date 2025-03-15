# Main deployment file with modules

# Modules
module "honeypot" {
  source = "./modules/honeypot"
}

module "log-analytics" {
  source = "./modules/log-analytics"
}

module "misp" {
  source = "./modules/misp"
}

module "network" {
  source = "./modules/network"
}

module "sentinel" {
  source = "./modules/sentinel"
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-Resources"
  location = "australiaeast"
}
