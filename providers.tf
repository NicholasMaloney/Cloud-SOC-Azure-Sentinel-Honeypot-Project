# Get current client config for tenant ID
data "azurerm_client_config" "current" {}

# Get current Azure AD client config
data "azuread_client_config" "current" {}

# Provider configurations (Azure RM, Azure AD)
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
  subscription_id = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}

# Configure the Microsoft Azure Active Directory Provider
provider "azuread" {
  tenant_id = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}

