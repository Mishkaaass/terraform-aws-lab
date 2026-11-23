# Inbound rules: NONE. Deliberately no SSH/RDP/HTTP ports on the EC2 instance.
resource "aws_security_group" "instance" {
  name_prefix            = "${var.name}-ec2-"
  description            = "No inbound; HTTPS only to private VPC"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true
  tags                   = merge(var.tags, { Name = "${var.name}-ec2-sg" })
}

# Use a modern standalone rule; do not mix this with inline egress rules.
resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.instance.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = var.vpc_cidr
  description       = "Only VPC internal HTTPS endpoints (SSM after endpoints are added)."
  tags              = var.tags
}
