output "name" {
  description = "Libvirt domain name."
  value       = libvirt_domain.server.name
}

output "ip_address" {
  description = "Guest IPv4 address learned from the libvirt DHCP lease."
  value = one(flatten([
    for interface in data.libvirt_domain_interface_addresses.server.interfaces : [
      for address in interface.addrs : address.addr
      if address.type == "ipv4"
    ]
  ]))
}

output "service_port" {
  description = "Application port associated with this server."
  value       = var.service_port
}
