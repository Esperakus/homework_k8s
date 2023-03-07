output "external_ip_address_ansible" {
  value = yandex_compute_instance.ansible.*.network_interface.0.nat_ip_address
}

output "internal_ip_address_k8s" {
  value = yandex_compute_instance.k8s.*.network_interface.0.ip_address
}