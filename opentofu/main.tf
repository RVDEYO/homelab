# Setup Proxmox VMs
resource "proxmox_virtual_environment_vm" "talos" {
  for_each  = { for node in local.nodes : node.hostname => node }
  name      = each.value.hostname
  node_name = "atlas"
  tags      = ["k8s"]
  vm_id     = each.value.vm_id
  bios      = "ovmf"
  machine   = "q35"

  agent {
    enabled = true
  }

  cpu {
    type  = "host"
    cores = each.value.cores
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    import_from  = data.proxmox_file.talos.id
  }

  scsi_hardware = "virtio-scsi-pci"

  efi_disk {
    datastore_id = "local-lvm"
    type         = "4m"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = "192.168.1.1"
      }
    }
  }
}

data "proxmox_file" "talos" {
  node_name    = "atlas"
  datastore_id = "local"
  content_type = "import"
  file_name    = "talosOS-nocloud-amd64.raw"
}

# Setup Talos cluster
resource "talos_machine_secrets" "this" {
  talos_version = "v1.13.7"
}

data "talos_machine_configuration" "this" {
  for_each         = { for node in local.nodes : node.hostname => node }
  cluster_name     = "homelab"
  cluster_endpoint = "https://192.168.1.220:6443"

  machine_type    = each.value.role
  machine_secrets = talos_machine_secrets.this.machine_secrets
}

data "talos_client_configuration" "this" {
  cluster_name         = "homelab"
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = ["192.168.1.220"]
  nodes                = [for node in local.nodes : node.ip]
}

resource "talos_machine_configuration_apply" "this" {
  for_each                    = { for node in local.nodes : node.hostname => node }
  depends_on                  = [proxmox_virtual_environment_vm.talos]
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration
  node                        = each.value.ip
  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
        }
      }
    }),
    yamlencode({
      cluster = {
        network = {
          cni = {
            name = "none"
          }
        }
      }
    }),
    yamlencode({
      cluster = {
        proxy = {
          disabled = true
        }
      }
    })
  ]
}

resource "talos_machine_bootstrap" "this" {
  depends_on           = [talos_machine_configuration_apply.this]
  node                 = "192.168.1.220"
  client_configuration = talos_machine_secrets.this.client_configuration
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = "192.168.1.220"
}

# Outputs for Talos configuration and kubeconfig
output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = resource.talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}
