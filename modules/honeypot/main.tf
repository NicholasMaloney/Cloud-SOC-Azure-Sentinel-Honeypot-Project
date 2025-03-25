# VM and related resources

# Look at docs on how to connect a VM to a data connector to send logs to a SIEM https://learn.microsoft.com/en-us/azure/sentinel/connect-data-sources?tabs=azure-portal
# https://learn.microsoft.com/en-us/azure/sentinel/connect-services-windows-based

# Honeypot VM      
resource "azurerm_windows_virtual_machine" "HP-VM" {
  name                              = "${var.prefix}-HP-VM"
  location                          = var.location
  resource_group_name               = var.rg_name
  network_interface_ids             = [var.HP-NIC-ID]
  size                              = "Standard_B1s"
  admin_username                    = "Synpathy"
  admin_password                    = "J!!L9&paoBRiD3Vq"
  vm_agent_platform_updates_enabled = true

  identity {
    type = "SystemAssigned"
  }

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

# AMA installation on Honeypot VM
resource "azurerm_virtual_machine_extension" "AMA-HP-WS1" {
  name                       = "${var.prefix}-AMA-HP-WS1"
  virtual_machine_id         = azurerm_windows_virtual_machine.HP-VM.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.32"
  auto_upgrade_minor_version = true

  depends_on = [azurerm_windows_virtual_machine.HP-VM]

  settings = <<SETTINGS
    {
      "workspaceId": "${var.LaWrkSpc_id}"
    }
  SETTINGS
}
