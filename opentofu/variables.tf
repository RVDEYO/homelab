variable "proxmox_endpoint" {
  description = "Endpoint for Proxmox Host"
  type        = string
}

variable "proxmox_username" {
  description = "Username for Proxmox Host"
  type        = string
  sensitive   = true
}

variable "proxmox_password" {
  description = "Password for Proxmox Host"
  type        = string
  sensitive   = true
}
