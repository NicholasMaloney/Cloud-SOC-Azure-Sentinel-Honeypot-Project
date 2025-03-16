
# Output MISP VM Public IP Address
output "MISP-VM-Public-IP" {
  value = azurerm_public_ip.MISP-pIP.ip_address
}
