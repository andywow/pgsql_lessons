variable "instance_count" {
  default     = 1
  description = "instance count"
}

variable "instance_prefix" {
  default     = "l05"
  description = "instance prefix"
}

variable "zone" {
  default     = "europe-north1-a"
  description = "Region"
}

variable "ssh_connection_user" {
  default     = "andy"
  description = "user for ssh connection"
}

variable "postgresql_install_mode" {
  default     = "standalone"
  description = "postgresql instal mode (standalone|docker)"
}

variable "create_disk" {
  default     = true
  description = "Create additional disk"
}

variable "allow_internet_traffic" {
  default     = false
  description = "Allow internet traffic"
}

