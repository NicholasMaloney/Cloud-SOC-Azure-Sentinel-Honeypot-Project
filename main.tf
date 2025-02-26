
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.20.0"
    }
  }
}

# Prefix for the resources
variable "prefix" {
  type    = string
  default = "Cloud-SOC"
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  subscription_id = "Enter-your-ID-here"
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-Resources"
  location = "australiaeast"
}

# ------- Network Configuration -------

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-Network"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

# Create a Subnet within the vNet
resource "azurerm_subnet" "internal" {
  name                 = "${var.prefix}-internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Create a public IP address - This will be assigned to the Win 11 VM 
resource "azurerm_public_ip" "public_ip" {
  name                 = "${var.prefix}-PublicIP"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  allocation_method    = "Dynamic"
  
}

# Create a Network Security Group (NSG) to allow RDP traffic
resource "azurerm_network_security_group" "NSG" {
    name                = "${var.prefix}-NSG"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    
    security_rule {
        name                       = "RDP"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3389"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

# Create a NIC for the VM | Specify the subnet private and public IP address
resource "azurerm_network_interface" "NIC" {
  name                 = "${var.prefix}-NIC"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name

    ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
    }

}

# ------- Log Analytics & Sentinel Configuration -------

# Create Log Analytics Workspace -> To collect successful and failed RDP logins
resource "azurerm_log_analytics_workspace" "LogAnalytics" {
  name                = "${var.prefix}-LogAnalytics"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
}

# Create Sentinel Workspace |  Connect Log Analytics to Sentinel
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "Sentinel" {
 workspace_id = azurerm_log_analytics_workspace.LogAnalytics.id
}

# Create Sentinel Rule - Successful RDP Login
resource "azurerm_sentinel_alert_rule_scheduled" "successful_rdp_login" {
 name                       = "${var.prefix}-SuccessfulRDPLogin"
 log_analytics_workspace_id = azurerm_log_analytics_workspace.LogAnalytics.workspace_id
 display_name               = "Successful RDP Login"
 severity                   = "High"
 tactics                    = ["InitialAccess"] 
 query_frequency            = "PT5M"
 query_period               = "PT5M"
 query                      = <<QUERY
SecurityEvent | 
    where Activity contains "success" and Account !contains "system"
QUERY
}

# Create Sentinel Rule - Failed RDP Login
resource "azurerm_sentinel_alert_rule_scheduled" "Failed_rdp_login" {
 name                       = "${var.prefix}-FailedRDPLogin"
 log_analytics_workspace_id = azurerm_log_analytics_workspace.LogAnalytics.workspace_id
 display_name               = "Failed RDP Login"
 severity                   = "Medium"
 tactics                    = ["CredentialAccess"] 
 query_frequency            = "PT5M"
 query_period               = "PT5M"
 query =                    <<QUERY
SecurityEvent
  | where EventID == 4625
  | summarize count() by TargetAccount, Computer, _ResourceID
QUERY
}


# ------- VM Configuration -------

# Create a Windows 11 VM with RDP internet facing.

# Note - In this release there's a known issue where the public_ip_address and public_ip_addresses fields may not  be fully populated for Dynamic Public IP's.
resource "azurerm_windows_virtual_machine" "WS01" {
  name                  = "${var.prefix}-WS01"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.NIC.id]
  size                  = "Standard_B1s"
  admin_username        = "Synpathy"           # Store these more securely
  admin_password        = "J!!L9&paoBRiD3Vq"   # <----------

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"  
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "win10-22h2-pro"
    version   = "latest"
  }

}

# Install Log Analytics Agent on the VM
resource "azurerm_virtual_machine_extension" "log_Analytics_Agent" {
  name = "${var.prefix}-LogAnalyticsAgent"
  virtual_machine_id = azurerm_windows_virtual_machine.WS01.id
  publisher = "Microsoft.EnterpriseCloud.Monitoring"
  type = "MicrosoftMonitoringAgent"
  type_handler_version = "1.0"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "workspaceId": "${azurerm_log_analytics_workspace.LogAnalytics.workspace_id}"
    }
  SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
      "workspaceKey": "${azurerm_log_analytics_workspace.LogAnalytics.primary_shared_key}"
    }
  PROTECTED_SETTINGS
}




