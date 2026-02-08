# ============================================================
# Secret Manager + Service Account
# ============================================================

# Service account for GCE instance
resource "google_service_account" "dashboard" {
  account_id   = "${var.instance_name}-vm"
  display_name = "CC Analyzer Dashboard VM"

  depends_on = [google_project_service.iam]
}

# ---- Grafana admin password ----

resource "google_secret_manager_secret" "grafana_admin_password" {
  secret_id = "${var.instance_name}-grafana-admin-password"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "grafana_admin_password" {
  secret      = google_secret_manager_secret.grafana_admin_password.id
  secret_data = var.grafana_admin_password
}

resource "google_secret_manager_secret_iam_member" "grafana_admin_password" {
  secret_id = google_secret_manager_secret.grafana_admin_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.dashboard.email}"
}

# ---- Tailscale auth key ----

resource "google_secret_manager_secret" "tailscale_auth_key" {
  secret_id = "${var.instance_name}-tailscale-auth-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "tailscale_auth_key" {
  secret      = google_secret_manager_secret.tailscale_auth_key.id
  secret_data = var.tailscale_auth_key
}

resource "google_secret_manager_secret_iam_member" "tailscale_auth_key" {
  secret_id = google_secret_manager_secret.tailscale_auth_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.dashboard.email}"
}

# ---- Google OAuth client secret ----

resource "google_secret_manager_secret" "google_oauth_client_secret" {
  secret_id = "${var.instance_name}-google-oauth-client-secret"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "google_oauth_client_secret" {
  secret      = google_secret_manager_secret.google_oauth_client_secret.id
  secret_data = var.google_oauth_client_secret
}

resource "google_secret_manager_secret_iam_member" "google_oauth_client_secret" {
  secret_id = google_secret_manager_secret.google_oauth_client_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.dashboard.email}"
}
