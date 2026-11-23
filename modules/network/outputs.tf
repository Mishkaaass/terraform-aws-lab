output "vpc_id" {
  value       = aws_vpc.this.id
  description = "VPC ID."
}
output "vpc_cidr" {
  value       = aws_vpc.this.cidr_block
  description = "VPC CIDR."
}
output "public_subnet_ids" {
  value       = [for k in sort(keys(aws_subnet.public)) : aws_subnet.public[k].id]
  description = "Two internet-routable public subnet IDs (without automatic public IPv4)."
}
output "private_subnet_ids" {
  value       = [for k in sort(keys(aws_subnet.private)) : aws_subnet.private[k].id]
  description = "Two isolated private subnet IDs with no NAT."
}
output "public_subnet_cidrs" {
  value = [for k in sort(keys(local.public_subnets)) : local.public_subnets[k].cidr]
}
output "private_subnet_cidrs" {
  value = [for k in sort(keys(local.private_subnets)) : local.private_subnets[k].cidr]
}
output "public_default_route_destination" {
  value = aws_route.public_internet.destination_cidr_block
}
