# Output variable declarations
output "AMA-HP-WS1-ID" {
  value = azurerm_virtual_machine_extension.AMA-HP-WS1.id
}

output "HP-VM-ID" {
  value = azurerm_windows_virtual_machine.HP-VM.id

}
