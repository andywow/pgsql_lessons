output "pgsql_standalone_ip" {
  value = module.pgsql_standalone.pgsql_external_ip
}

output "pgsql_docker_ip" {
  value = module.pgsql_docker.pgsql_external_ip
}
