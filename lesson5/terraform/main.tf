# common config
terraform {
  required_providers {
    google = {
      version = "~> 3.47.0"
    }
    null = {
      version = "~> 3.0.0"
    }
  }
}

# Google provider settings
provider "google" {
  project = var.project
  region  = var.region
}

# default network
data "google_compute_network" "default" {
  name = "default"
}

# firewall rule
resource "google_compute_firewall" "pgsql_firewall" {

  name    = "default-allow-postgresql"
  network = data.google_compute_network.default.name

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  target_tags = ["pgsql-allow-traffic"]

}

# standalone pgsql instance
module "pgsql_standalone" {
  source          = "./modules/pgsql"
  instance_prefix = "l05-standalone"
}

# docker pgsql instance
module "pgsql_docker" {
  source                  = "./modules/pgsql"
  instance_prefix         = "l05-docker"
  postgresql_install_mode = "docker"
  create_disk             = false
  allow_internet_traffic  = true
}
