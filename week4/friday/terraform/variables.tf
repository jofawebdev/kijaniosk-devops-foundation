variable "ssh_public_key_path" {
  description = "Path to the SSH public key used for guest access."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}
