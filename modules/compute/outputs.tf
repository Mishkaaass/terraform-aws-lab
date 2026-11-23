output "instance_id" { value = try(aws_instance.this[0].id, null) }
output "instance_count" { value = length(aws_instance.this) }
output "has_public_ipv4" { value = try(aws_instance.this[0].associate_public_ip_address, false) }
output "imdsv2_required" { value = try(aws_instance.this[0].metadata_options[0].http_tokens == "required", false) }
output "root_disk_encrypted" { value = try(aws_instance.this[0].root_block_device[0].encrypted, false) }
output "has_ssh_key" { value = try(aws_instance.this[0].key_name != null, false) }
