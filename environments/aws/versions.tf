terraform {
  required_version = ">= 1.17.0, < 1.18.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.73.0"
    }
  }
}
