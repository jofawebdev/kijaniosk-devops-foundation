locals {
  servers = {
    api = {
      service_port = 3000
      memory_mib   = 1024
    }
    payments = {
      service_port = 3001
      memory_mib   = 1024
    }
    logs = {
      service_port = 3010
      memory_mib   = 1024
    }
  }
}

resource "libvirt_volume" "ubuntu_base" {
  name = "kijanikiosk-ubuntu-22.04-base.qcow2"
  pool = "default"

  create = {
    content = {
      url = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
    }
  }
}

module "app_server" {
  for_each = local.servers

  source = "./modules/app_server"

  name            = each.key
  service_port    = each.value.service_port
  memory_mib      = each.value.memory_mib
  base_image_path = libvirt_volume.ubuntu_base.path
  ssh_public_key  = trimspace(file(pathexpand(var.ssh_public_key_path)))
}
