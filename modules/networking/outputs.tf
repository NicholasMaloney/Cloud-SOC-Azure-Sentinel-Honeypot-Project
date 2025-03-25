
# Output MISP VM Public IP Address
output "MISP-VM-Public-IP" {
  value = azurerm_public_ip.MISP-pIP.ip_address
}

output "HP-NIC-ID" {
  value = azurerm_network_interface.HP-NIC.id
}

output "MISP-NIC-ID" {
  value = azurerm_network_interface.MISP-NIC.id
}

