# Separate state from AWS and Floci. Owns only a dedicated VM storage pool.
# Reuses existing "default" libvirt NAT network; never changes host routing/firewalls.
locals {
  vm_name = var.vm_name
}

resource "libvirt_pool" "lab" {
  name = "tfaws-lab"
  type = "dir"

  target = {
    path = "/var/lib/libvirt/images/tfaws-lab"
  }

  create = {
    autostart = false
  }

  # Delete volumes explicitly before removing the pool; keep the directory safe.
  destroy = {
    delete = false
  }
}

resource "libvirt_volume" "ubuntu_base" {
  name = "${local.vm_name}-ubuntu2404-base.qcow2"
  pool = libvirt_pool.lab.name
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
  pool     = libvirt_pool.lab.name
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
  pool = libvirt_pool.lab.name

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
    # Recovery display: visible even before the guest network or SSH works.
    # Bind VNC to host loopback only; do not expose a management console to LAN.
    graphics = [
      {
        vnc = {
          auto_port = true
          listen    = "127.0.0.1"
        }
      }
    ]

    videos = [
      {
        model = {
          type    = "vga"
          primary = "yes"
        }
      }
    ]

    disks = [
      {
        # File reference lets virt-aa-helper discover the qcow2 backing chain
        # and allow AppArmor access to the Ubuntu base image.
        source = {
          file = {
            file = libvirt_volume.root.path
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
        # Refer directly to the seed ISO so the guest's AppArmor profile
        # includes it, just as with the root qcow2 disk.
        source = {
          file = {
            file = libvirt_volume.seed.path
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
