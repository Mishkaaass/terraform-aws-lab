# REAL AWS. Do not run terraform apply here until account/cost checks are complete.
data "aws_availability_zones" "available" {
  state = "available"
}
# Read the official AMI only if an EC2 instance is explicitly requested.
data "aws_ssm_parameter" "al2023" {
  count = var.enable_compute ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
locals {
  zones = slice(data.aws_availability_zones.available.names, 0, 2)
  tags = {
    Project     = var.project_name
    Environment = "aws-demo"
    ManagedBy   = "Terraform"
    Owner       = "portfolio-lab"
  }
}
module "network" {
  source             = "../../modules/network"
  name               = var.project_name
  vpc_cidr           = "10.42.0.0/16"
  availability_zones = local.zones
  tags               = local.tags
}
module "security" {
  source   = "../../modules/security"
  name     = var.project_name
  vpc_id   = module.network.vpc_id
  vpc_cidr = module.network.vpc_cidr
  tags     = local.tags
}
module "identity" {
  source = "../../modules/identity"
  name   = var.project_name
  tags   = local.tags
}
module "compute" {
  source                = "../../modules/compute"
  name                  = var.project_name
  enabled               = var.enable_compute
  ami_id                = var.enable_compute ? data.aws_ssm_parameter.al2023[0].value : "ami-00000000000000000"
  instance_type         = "t3.micro"
  subnet_id             = module.network.private_subnet_ids[0]
  security_group_id     = module.security.instance_security_group_id
  instance_profile_name = module.identity.instance_profile_name
  tags                  = local.tags
}
