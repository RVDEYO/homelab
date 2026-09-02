locals {
  nodes = [
    {
      hostname = "controlplane"
      ip       = "192.168.1.220"
      cores    = 4
      memory   = 4 * 1024,
      vm_id    = 200
      role     = "controlplane"
      disk     = 32 
    },
    {
      hostname = "worker01"
      ip       = "192.168.1.221"
      cores    = 4
      memory   = 4 * 1024,
      vm_id    = 201
      role     = "worker"
      disk     = 64 
    },
    {
      hostname = "worker02"
      ip       = "192.168.1.222"
      cores    = 4
      memory   = 4 * 1024,
      vm_id    = 202
      role     = "worker"
      disk     = 64
    }
  ]

}
