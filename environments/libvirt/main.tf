# Separate state from AWS and Floci. Uses only the already-existing libvirt "default"
# network and storage pool; no host bridges, firewall, DNS or existing VMs are edited.
locals {
  vm_name = var.vm_name
}

resource "libvirt_volume" "ubuntu_base" {
  name = "${local.vm_name}-ubuntu2404-base.qcow2"
  pool = "default"
  target = {
    format = {
      type = "qcow2"
    }
  }

  create = {
    content = {
      url = pathexpand(var.base_image_path)
    }
  }
}

resource "libvirt_volume" "root" {
  name     = "${local.vm_name}-root.qcow2"
  pool     = "default"
  capacity = 8 * 1024 * 1024 * 1024
  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    path = libvirt_volume.ubuntu_base.path
    format = {
      type = "qcow2"
    }
  }
}

resource "libvirt_cloudinit_disk" "seed" {
  name = "${local.vm_name}-seed"

  meta_data = yamlencode({
    "instance-id"    = "${local.vm_name}-001"
    "local-hostname" = local.vm_name
  })

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    ssh_public_key = trimspace(var.ssh_public_key)
  })
}

resource "libvirt_volume" "seed" {
  name = "${local.vm_name}-cloudinit.iso"
  pool = "default"

  create = {
    content = {
      url = libvirt_cloudinit_disk.seed.path
    }
  }
}

resource "libvirt_domain" "vm" {
  name        = local.vm_name
  type        = "kvm"
  memory      = var.memory_mib
  memory_unit = "MiB"
  vcpu        = var.vcpus
  running     = true
  autostart   = false

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
  }

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool   = libvirt_volume.root.pool
            volume = libvirt_volume.root.name
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
        driver = {
          type = "qcow2"
        }
      },
      {
        device = "cdrom"
        source = {
          volume = {
            pool   = libvirt_volume.seed.pool
            volume = libvirt_volume.seed.name
          }
        }
        target = {
          dev = "sda"
          bus = "sata"
        }
      }
    ]

    interfaces = [
      {
        type = "network"
        model = {
          type = "virtio"
        }
        source = {
          network = {
            network = "default"
          }
        }
      }
    ]
  }
}
