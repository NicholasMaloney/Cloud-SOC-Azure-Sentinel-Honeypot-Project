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
  allocation_method    = "Static"
  sku                  = "Standard"
  
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

resource "azurerm_subnet_network_security_group_association" "HP-NSG-Association" {
  subnet_id                 = azurerm_subnet.HP-internal.id
  network_security_group_id = azurerm_network_security_group.HP-NSG.id
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
resource "azurerm_windows_virtual_machine" "HP-WS1" {
  name                  = "${var.prefix}-HPVM"
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