# SSH access (restrict to admin IP)
resource "google_compute_firewall" "ssh" {
  name    = "${var.instance_name}-allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allowed_ssh_cidrs
  target_tags   = ["cc-dashboard"]
}

# OTEL Collector gRPC (receives telemetry from team members)
resource "google_compute_firewall" "otel" {
  name    = "${var.instance_name}-allow-otel"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["4317"]
  }

  source_ranges = ["0.0.0.0/0"] # お試しフェーズ: 全開放
  target_tags   = ["cc-dashboard"]
}

# Grafana dashboard (web UI)
resource "google_compute_firewall" "grafana" {
  name    = "${var.instance_name}-allow-grafana"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  source_ranges = ["0.0.0.0/0"] # お試しフェーズ: 全開放（Grafana認証あり）
  target_tags   = ["cc-dashboard"]
}
