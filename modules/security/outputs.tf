output "instance_security_group_id" {
  value = aws_security_group.instance.id
}
output "ingress_rule_count" {
  # There are no aws_vpc_security_group_ingress_rule resources in this module.
  value = length(aws_security_group.instance.ingress)
}
output "egress_port" {
  value = aws_vpc_security_group_egress_rule.https.from_port
}
output "egress_cidr" {
  value = aws_vpc_security_group_egress_rule.https.cidr_ipv4
}
