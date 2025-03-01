# Environment Configuration
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.21.1"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  subscription_id = ""
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-Resources"
  location = "australiaeast"
}