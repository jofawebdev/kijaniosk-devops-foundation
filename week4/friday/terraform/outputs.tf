output "server_ips" {
  description = "Dynamically discovered IP addresses for the application servers."
  value = {
    for name, server in module.app_server : name => server.ip_address
  }
}

output "server_names" {
  description = "Libvirt domain names for the application servers."
  value = {
    for name, server in module.app_server : name => server.name
  }
}

output "service_ports" {
  description = "Application service port assigned to each server."
  value = {
    for name, server in module.app_server : name => server.service_port
  }
}
