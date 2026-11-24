variable "vm_name" {
  description = "Unique name for this lab VM. No existing libvirt domains are modified."
  type        = string
  default     = "tfaws-lab01"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,31}$", var.vm_name))
    error_message = "vm_name must be 3-32 lowercase letters, digits or hyphens and start with a letter."
  }
}

variable "memory_mib" {
  description = "Guest memory in MiB. Default 1.5 GiB keeps the laptop responsive."
  type        = number
  default     = 1536

  validation {
    condition     = var.memory_mib >= 1024 && var.memory_mib <= 3072
    error_message = "For this laptop lab, memory_mib must be 1024-3072."
  }
}

variable "vcpus" {
  description = "Virtual CPU count."
  type        = number
  default     = 2

  validation {
    condition     = var.vcpus >= 1 && var.vcpus <= 4 && floor(var.vcpus) == var.vcpus
    error_message = "Use 1-4 integer vCPUs."
  }
}

variable "base_image_path" {
  description = "Locally verified Ubuntu 24.04 cloud image. Never fetched by Terraform from an arbitrary URL."
  type        = string
  default     = "~/.cache/terraform-aws-lab/images/noble-server-cloudimg-amd64.img"
}

variable "ssh_public_key" {
  description = "SSH public key only. Supply via TF_VAR_ssh_public_key; never pass a private key."
  type        = string
  sensitive   = false

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-[^ ]+) [A-Za-z0-9+/=]+", trimspace(var.ssh_public_key)))
    error_message = "Provide the contents of an SSH PUBLIC key (.pub file)."
  }
}
