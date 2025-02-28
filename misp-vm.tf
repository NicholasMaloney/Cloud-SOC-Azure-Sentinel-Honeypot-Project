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
  allocation_method    = "Static"
  sku                  = "Standard" 
  
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
  disable_password_authentication = false

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"  
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

# MISP VM Initial Configuration - Install Docker and MISP
resource "azurerm_virtual_machine_run_command" "MISP-VM-Initial-Config" {
  name               = "MISP-Install"
  location           = azurerm_resource_group.rg.location
  virtual_machine_id = azurerm_linux_virtual_machine.MISP-VM.id
  # This script installs Docker -> MISP & edits the env file to reflect the public IP address
  source {
    script = <<EOT
#!/bin/bash
set -e  # Exit on error

# Log setup
exec 1> >(logger -s -t $(basename $0)) 2>&1

# Error handling
handle_error() {
    logger "An error occurred on line $1"
    exit 1
}
trap 'handle_error $LINENO' ERR

# Installing Docker on Ubuntu
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release git
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Clone MISP Docker repository
git clone https://github.com/MISP/misp-docker.git
cd misp-docker
cp template.env .env

# Get the public IP address using Azure Instance Metadata Service
PUBLIC_IP=$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01&format=text")

# Update the BASE_URL in the .env file
sed -i "s#BASE_URL=.*#BASE_URL=https://$${PUBLIC_IP}#g" .env

# Start the MISP Docker container
sudo docker compose pull
sudo docker compose up -d

# Wait for MISP to be ready
echo "Waiting for MISP to start..."
sleep 60

# Check if MISP is running
if ! sudo docker compose ps | grep -q "Up"; then
    echo "MISP failed to start"
    sudo docker compose logs
    exit 1
fi

echo "MISP installation completed successfully"
    EOT
  }
}