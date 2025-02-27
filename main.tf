# Environment Configuration
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

# ------- Win 10 Honey Pot VM Configuration -------

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "HP-Network" {
  name                = "${var.prefix}-HP-vNetwork"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

# Create a Subnet within the vNet
resource "azurerm_subnet" "HP-internal" {
  name                 = "${var.prefix}-HP-internal-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.HP-Network.name
  address_prefixes     = ["10.0.2.0/24"]
}

#  Win 10 honeypot VM public IP address 
resource "azurerm_public_ip" "HP-public_ip" {
  name                 = "${var.prefix}-HP-PublicIP"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  allocation_method    = "Dynamic"
  
}

# Win 10 honeypot VM Network Security Group (NSG) | Exposes/Allows RDP to public internet 
resource "azurerm_network_security_group" "HP-NSG" {
    name                = "${var.prefix}-HP-NSG"
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

# Windows honeypot VM NIC | Specify the subnet private and public IP address
resource "azurerm_network_interface" "HP-NIC" {
  name                 = "${var.prefix}-HP-NIC"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name

    ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.HP-internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.HP-public_ip.id
    }

}

# Create a Windows 10 VM with RDP internet facing.
# Note - In this release there's a known issue where the public_ip_address and public_ip_addresses fields may not  be fully populated for Dynamic Public IP's.
resource "azurerm_windows_virtual_machine" "HP-WS01" {
  name                  = "${var.prefix}-HP-WS01"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.HP-NIC.id]
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

# ------- MISP / Ubuntu VM Configuration -------

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "MISP-Network" {
  name                = "${var.prefix}-MISP-vNetwork"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

# Create a Subnet within the vNet
resource "azurerm_subnet" "MISP-internal" {
  name                 = "${var.prefix}-MISP-internal-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.MISP-Network.name
  address_prefixes     = ["10.0.3.0/24"]
  
}

# Create a public IP address - This will be assigned to the Ubuntu VM
resource "azurerm_public_ip" "MISP_public_ip" {
  name                 = "${var.prefix}-MISP-PublicIP"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  allocation_method    = "Dynamic"
  
}
# Unbuntu Server (MISP) Network Security Group (NSG) - Allows HTTPS traffic on port 443 so you can access the MISP web interface
resource "azurerm_network_security_group" "MISP-NSG" {
  name = "${var.prefix}-MISP-NSG"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-HTTPS-Traffic-MISP"
    priority                   = 310
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Linux VM NIC for MISP - Threat Intelligence Platform
resource "azurerm_network_interface" "MISP-NIC" {
  name                 = "${var.prefix}-MISP-NIC"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name

    ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.MISP-internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.MISP_public_ip.id
    }

}

# Ubuntu VM for MISP - Threat Intelligence Platform
resource "azurerm_linux_virtual_machine" "MISP-VM" {
  name                  = "${var.prefix}-MISP-VM"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = "Standard_B1s"
  admin_username        = "Synpathy-Ubuntu"           # Store these more securely
  admin_password        = "J!!L9&paoBRiD3Vq"   # <----------
  network_interface_ids = [azurerm_network_interface.MISP-NIC.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"  
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "20.04-LTS"
    version   = "latest"
  }

}

# MISP VM Initial Configuration - Install Docker and MISP
resource "azurerm_virtual_machine_run_command" "example" {
  name               = "example-vmrc"
  location           = azurerm_resource_group.rg.location
  virtual_machine_id = azurerm_linux_virtual_machine.MISP-VM.id
  # This script installs Docker -> MISP & edits the env file to reflect the public IP address
  source {
    script = <<EOT
      #!/bin/bash

      #Installing Docker on Ubuntu
      sudo apt-get update
      sudo apt-get install ca-certificates curl
      sudo install -m 0755 -d /etc/apt/keyrings
      sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
      sudo chmod a+r /etc/apt/keyrings/docker.asc
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      sudo apt-get update
     
     # Clone MISP Docker repository
     git clone https://github.com/misp/misp-docker.git
     cd misp-docker
     cp template.env .env

     # Get the public IP address of the VM
     PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

     # Update the BASE_URL in the .env file
     sed -i "s|BASE_URL=.*|BASE_URL=http://$PUBLIC_IP|g" .env

     # Start the MISP Docker container
     sudo docker compose pull
     sudo docker compose up
   EOT 
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

# Installing Log Analytics Agent on the Windows 10 Honey Pot VM
resource "azurerm_virtual_machine_extension" "log_Analytics_Agent" {
  name                       = "${var.prefix}-LogAnalyticsAgent"
  virtual_machine_id         = azurerm_windows_virtual_machine.HP-WS01.id
  publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
  type                       = "MicrosoftMonitoringAgent"
  type_handler_version       = "1.0"
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

# Create Sentinel Workspace |  Connect Log Analytics to Sentinel
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "Sentinel" {
 workspace_id = azurerm_log_analytics_workspace.LogAnalytics.id
}

# Create Sentinel Rule - Successful RDP Login - Win 10 HP VM 
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

# Create Sentinel Rule - Failed RDP Login - Win 10 HP VM 
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