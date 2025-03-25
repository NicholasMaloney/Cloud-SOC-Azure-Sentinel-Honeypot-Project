
# ------------------------------------- Honeypot VM Network configuration ------------------------------------- #
# Virtual network for Honeypot VM 
resource "azurerm_virtual_network" "HP-vNet" {
  name                = "${var.prefix}-HP-vNet"
  resource_group_name = var.rg_name
  location            = var.location
  address_space       = ["10.100.0.0/24"]
}

# Honeypot subnet 
resource "azurerm_subnet" "HP-sNet" {
  name                 = "${var.prefix}-HP-sNet"
  resource_group_name  = var.rg_name
  virtual_network_name = azurerm_virtual_network.HP-vNet.name
  address_prefixes     = ["10.100.0.0/24"]
}

# Honeypot Public IP address
resource "azurerm_public_ip" "HP-pIP" {
  name                = "${var.prefix}-HP-pIP"
  location            = var.location
  resource_group_name = var.rg_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Honeypot NIC 
resource "azurerm_network_interface" "HP-NIC" {
  name                = "${var.prefix}-HP-NIC"
  location            = var.location
  resource_group_name = var.rg_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.HP-sNet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.HP-pIP.id
  }

}

# Honeypot Network Security Group (NSG) | Exposes/Allows RDP to public internet
resource "azurerm_network_security_group" "HP-NSG" {
  name                = "${var.prefix}-HP-NSG"
  location            = var.location
  resource_group_name = var.rg_name

  security_rule {
    name                       = "RDP"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAzureMonitor"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureMonitor"
  }
}

# Associate the Honeypot NSG with the Honeypot subnet
resource "azurerm_subnet_network_security_group_association" "HP-NSG-Association" {
  subnet_id                 = azurerm_subnet.HP-sNet.id
  network_security_group_id = azurerm_network_security_group.HP-NSG.id
}

# ------------------------------------- MISP Network configuration  ------------------------------------- #

# Virtual network for MISP VM 
resource "azurerm_virtual_network" "MISP-vNet" {
  name                = "${var.prefix}-MISP-vNet"
  resource_group_name = var.rg_name
  location            = var.location
  address_space       = ["10.200.0.0/24"]
}

# MISP subnet 
resource "azurerm_subnet" "MISP-sNet" {
  name                 = "${var.prefix}-MISP-sNet"
  resource_group_name  = var.rg_name
  virtual_network_name = azurerm_virtual_network.MISP-vNet.name
  address_prefixes     = ["10.200.0.0/24"]
}

# MISP Public IP address
resource "azurerm_public_ip" "MISP-pIP" {
  name                = "${var.prefix}-MISP-pIP"
  location            = var.location
  resource_group_name = var.rg_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# MISP NIC
resource "azurerm_network_interface" "MISP-NIC" {
  name                = "${var.prefix}-MISP-NIC"
  location            = var.location
  resource_group_name = var.rg_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.MISP-sNet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.MISP-pIP.id
  }

}

# MISP Network Security Group (NSG) - Allows HTTPS traffic on port 443 so you can access the MISP web interface
resource "azurerm_network_security_group" "MISP-NSG" {
  name                = "${var.prefix}-MISP-NSG"
  location            = var.location
  resource_group_name = var.rg_name

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

  security_rule {
    name                       = "Allow-Required-Outbound-Traffic"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "442-446"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }

}

# Associate the MISP NSG with the MISP subnet
resource "azurerm_subnet_network_security_group_association" "MISP-NSG-Association" {
  subnet_id                 = azurerm_subnet.MISP-sNet.id
  network_security_group_id = azurerm_network_security_group.MISP-NSG.id
}
