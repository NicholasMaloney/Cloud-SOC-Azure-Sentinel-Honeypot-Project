# Environment Configuration
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.21.1"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">=3.1.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}

provider "azuread" {
  tenant_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-Resources"
  location = "australiaeast"
}