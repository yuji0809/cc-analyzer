# Static IP address
resource "google_compute_address" "dashboard" {
  name   = "${var.instance_name}-ip"
  region = var.region
}

# GCE instance (e2-micro = Always Free tier)
resource "google_compute_instance" "dashboard" {
  name         = var.instance_name
  machine_type = "e2-micro"
  zone         = var.zone

  tags = ["cc-dashboard"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = 30   # GB - Always Free limit
      type  = "pd-standard" # Must be standard for Always Free
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.dashboard.address
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_pub_key_path)}"
  }

  metadata_startup_script = templatefile("${path.module}/startup.sh", {
    grafana_admin_password = var.grafana_admin_password
  })

  # Prevent Ops Agent (not needed, saves resources)
  service_account {
    scopes = ["compute-ro"]
  }

  scheduling {
    # Preemptible = false for Always Free (default)
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  lifecycle {
    ignore_changes = [metadata_startup_script]
  }
}
