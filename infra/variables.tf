variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region (must be us-central1, us-west1, or us-east1 for Always Free)"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "instance_name" {
  description = "Name of the GCE instance"
  type        = string
  default     = "cc-analyzer"
}

variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "tailscale_auth_key" {
  description = "Tailscale auth key (generate at https://login.tailscale.com/admin/settings/keys)"
  type        = string
  sensitive   = true
}

variable "google_oauth_client_id" {
  description = "Google OAuth Client ID for Grafana SSO (create at GCP Console > APIs & Services > Credentials)"
  type        = string
}

variable "google_oauth_client_secret" {
  description = "Google OAuth Client Secret for Grafana SSO"
  type        = string
  sensitive   = true
}

variable "google_oauth_allowed_domain" {
  description = "Allowed Google Workspace domain for Grafana login (e.g. yourcompany.com)"
  type        = string
}
