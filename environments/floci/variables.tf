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
  description = "Do not enable in regular Floci mode without the Docker socket; Terraform mock tests still cover EC2."
}
