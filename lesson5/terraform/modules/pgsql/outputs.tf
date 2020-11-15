output "pgsql_external_ip" {
  value = google_compute_instance.pgsql.*.network_interface.0.access_config.0.nat_ip
}
