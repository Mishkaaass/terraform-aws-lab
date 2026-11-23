# Real AWS root, completely separated from Floci credentials/endpoints.
provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.expected_account_id]
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "aws-demo"
      ManagedBy   = "Terraform"
      Owner       = "portfolio-lab"
    }
  }
}
