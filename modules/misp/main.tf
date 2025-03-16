
# Ubuntu Linux VM for MISP - Threat Intelligence Platform
resource "azurerm_linux_virtual_machine" "MISP-VM" {
  name                            = "${var.prefix}-MISP-VM"
  location                        = var.location
  resource_group_name             = var.rg_name
  size                            = "Standard_D2s_v3"
  admin_username                  = "Synpathy-Ubuntu"  # Store these more securely
  admin_password                  = "J!!L9&paoBRiD3Vq" # <----------
  network_interface_ids           = [azurerm_network_interface.MISP-NIC.id]
  disable_password_authentication = false

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

# MISP VM Initial Configuration - Install Docker and MISP
resource "azurerm_virtual_machine_run_command" "misp_vm_initial_config" {
  name               = "MISP-Docker-Install"
  location           = var.location
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
  timeouts {
    create = "60m"
  }

  depends_on = [
    azurerm_linux_virtual_machine.MISP-VM
  ]

}
