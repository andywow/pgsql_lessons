# ubuntu base image
data "google_compute_image" "ubuntu_image" {
  family  = "ubuntu-2004-lts"
  project = "ubuntu-os-cloud"
}

locals {
  traffic_policy_tag = var.allow_internet_traffic ? "pgsql-allow-traffic" : "pgsql-deny-traffic"
}

# pgsql instance
resource "google_compute_instance" "pgsql" {
  count        = var.instance_count
  name         = "pgsql-${var.instance_prefix}-${count.index + 1}"
  machine_type = "e2-medium"
  zone         = var.zone
  tags         = ["pgsql", local.traffic_policy_tag]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu_image.self_link
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"
    access_config {
    }
  }

  scheduling {
    automatic_restart = false
    preemptible       = true
  }

  lifecycle {
    ignore_changes = [attached_disk]
  }

  connection {
    host        = self.network_interface.0.access_config.0.nat_ip
    user        = var.ssh_connection_user
    private_key = file("~/.ssh/id_rsa")
  }

  # provision postgresql
  provisioner "ansible" {

    plays {
      playbook {
        file_path  = "${path.module}/../../../ansible/playbooks/postgresql.yml"
        roles_path = ["${path.module}/../../../ansible/roles"]
      }

      extra_vars = {
        postgresql_install_mode = var.postgresql_install_mode
      }

      verbose = true
    }

    ansible_ssh_settings {
      connect_timeout_seconds              = 20
      connection_attempts                  = 20
      ssh_keyscan_timeout                  = 120
      insecure_no_strict_host_key_checking = true
    }

  }

}

# additional disk
resource "google_compute_disk" "pgsql_disk" {
  count = var.create_disk ? var.instance_count : 0

  name = "pgsql-add-${var.instance_prefix}-${count.index + 1}"
  type = "pd-standard"
  zone = var.zone
  size = 10
}

# attach disk
resource "google_compute_attached_disk" "pgsql_attached_disk" {
  count = var.create_disk ? var.instance_count : 0
  depends_on = [
    google_compute_disk.pgsql_disk,
    google_compute_instance.pgsql
  ]

  disk     = google_compute_disk.pgsql_disk[count.index].id
  instance = google_compute_instance.pgsql[count.index].id
}

# move db by playbook
resource "null_resource" "pgsql_remount_disk" {
  count = var.create_disk ? var.instance_count : 0
  depends_on = [
    google_compute_attached_disk.pgsql_attached_disk
  ]

  connection {
    host        = google_compute_instance.pgsql[count.index].network_interface.0.access_config.0.nat_ip
    user        = var.ssh_connection_user
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "ansible" {

    plays {
      playbook {
        file_path  = "${path.module}/../../../ansible/playbooks/postgresql.yml"
        roles_path = ["${path.module}/../../../ansible/roles"]
      }

      extra_vars = {
        postgresql_install_mode = "movedb"
      }

      verbose = true
    }

    ansible_ssh_settings {
      connect_timeout_seconds              = 20
      connection_attempts                  = 20
      ssh_keyscan_timeout                  = 60
      insecure_no_strict_host_key_checking = true
    }

  }

}
