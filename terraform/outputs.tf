output "key_data" {
  value = azapi_resource_action.ssh_public_key_gen.output.publicKey
}

output "ssh_private_key_path" {
  value       = local_file.ssh_private_key.filename
  description = "Path to the generated SSH private key file."
}

output "ssh_public_key" {
  value = azapi_resource_action.ssh_public_key_gen.output.publicKey
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "public_ip_address" {
  value = azurerm_linux_virtual_machine.my_terraform_vm.public_ip_address
}
