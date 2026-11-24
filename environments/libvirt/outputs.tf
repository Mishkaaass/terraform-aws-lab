output "vm_name" {
  description = "The VM managed by this isolated Terraform root."
  value       = libvirt_domain.vm.name
}

output "vm_uuid" {
  description = "Libvirt UUID, useful for finding the VM."
  value       = libvirt_domain.vm.uuid
}

output "network" {
  description = "Existing libvirt NAT network used by the VM."
  value       = "default"
}

output "health_check_path" {
  description = "Read-only HTTP health endpoint on guest port 8080."
  value       = "/health"
}
