output "vpc_id" { value = module.network.vpc_id }
output "public_subnet_ids" { value = module.network.public_subnet_ids }
output "private_subnet_ids" { value = module.network.private_subnet_ids }
output "security_group_id" { value = module.security.instance_security_group_id }
output "instance_id" { value = module.compute.instance_id }
output "instance_count" { value = module.compute.instance_count }
