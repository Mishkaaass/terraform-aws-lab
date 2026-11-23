locals {
  tags = {
    Project     = var.project_name
    Environment = "floci"
    ManagedBy   = "Terraform"
    Owner       = "portfolio-lab"
  }
}
module "network" {
  source             = "../../modules/network"
  name               = var.project_name
  vpc_cidr           = "10.42.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
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
  ami_id                = "ami-0abcdef1234567891" # Floci's Amazon Linux 2023 catalog AMI
  instance_type         = "t3.micro"
  subnet_id             = module.network.private_subnet_ids[0]
  security_group_id     = module.security.instance_security_group_id
  instance_profile_name = module.identity.instance_profile_name
  tags                  = local.tags
}
