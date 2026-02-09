# Static IP address
resource "google_compute_address" "dashboard" {
  name   = "${var.instance_name}-ip"
  region = var.region

  depends_on = [google_project_service.compute]
}

# GCE instance (e2-micro = Always Free tier)
resource "google_compute_instance" "dashboard" {
  name         = var.instance_name
  machine_type = "e2-micro"
  zone         = var.zone

  tags = ["cc-analyzer"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = 30            # GB - Always Free limit
      type  = "pd-standard" # Must be standard for Always Free
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.dashboard.address
    }
  }

  metadata_startup_script = templatefile("${path.module}/startup.sh", {
    project_id                  = var.project_id
    grafana_admin_user          = var.grafana_admin_user
    google_oauth_client_id      = var.google_oauth_client_id
    google_oauth_allowed_domain = var.google_oauth_allowed_domain
    docker_compose              = file("${path.module}/docker-compose.yml")
    otel_collector_config       = file("${path.module}/otel-collector-config.yaml")
    grafana_datasources         = file("${path.module}/grafana/provisioning/datasources/datasources.yml")
    grafana_dashboards          = file("${path.module}/grafana/provisioning/dashboards/dashboards.yml")
    instance_name               = var.instance_name
    grafana_team_template       = file("${path.module}/grafana/provisioning/dashboards/team-template.json")
  })

  service_account {
    email  = google_service_account.dashboard.email
    scopes = ["cloud-platform"]
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
