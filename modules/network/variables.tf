variable "name" {
  type        = string
  description = "Resource name prefix."
}
variable "vpc_cidr" {
  type        = string
  description = "Private VPC IPv4 CIDR. Minimum /16 for the subnet layout."
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr)) && can(cidrsubnet(var.vpc_cidr, 8, 11))
    error_message = "vpc_cidr must be valid IPv4 and large enough for /24-like subnets."
  }
}
variable "availability_zones" {
  type        = list(string)
  description = "Exactly two distinct AWS availability zones."
  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "Pass exactly two distinct availability zones."
  }
}
variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to every supported resource."
}
