variable "expected_account_id" {
  type        = string
  description = "REQUIRED 12-digit AWS account ID; must match sts get-caller-identity."
  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "Provide a 12-digit AWS account ID."
  }
}
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "project_name" {
  type    = string
  default = "terraform-aws-lab"
  validation {
    condition     = can(regex("^[a-z0-9-]{3,28}$", var.project_name))
    error_message = "Use 3-28 lowercase alphanumeric or hyphen characters."
  }
}
variable "enable_compute" {
  type        = bool
  default     = false
  description = "COST INCURRING; private EC2 is disabled by default."
}
