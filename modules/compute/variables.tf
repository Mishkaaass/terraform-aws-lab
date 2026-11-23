variable "name" { type = string }
variable "enabled" {
  type        = bool
  default     = false
  description = "False by default to avoid cloud charges and Docker-socket requirements."
}
variable "ami_id" { type = string }
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
variable "subnet_id" { type = string }
variable "security_group_id" { type = string }
variable "instance_profile_name" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
