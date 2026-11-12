variable "name" {
  description = "Unique application server name."
  type        = string
}

variable "service_port" {
  description = "Application service port assigned to this server."
  type        = number
}

variable "base_image_path" {
  description = "Absolute path to the shared Ubuntu base image."
  type        = string
}

variable "ssh_public_key" {
  description = "Public SSH key installed for the Ubuntu administrator."
  type        = string
}

variable "memory_mib" {
  description = "Guest memory in MiB."
  type        = number
  default     = 1024
}

variable "vcpu" {
  description = "Number of virtual CPUs."
  type        = number
  default     = 1
}
