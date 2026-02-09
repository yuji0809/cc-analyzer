output "instance_ip" {
  description = "Public IP address (for reference only, services are not exposed)"
  value       = google_compute_address.dashboard.address
}

output "grafana_url" {
  description = "Grafana dashboard URL (Tailscale HTTPS)"
  value       = "https://${var.instance_name}.<tailnet>.ts.net (check Tailscale Admin Console for exact FQDN)"
}

output "otel_endpoint" {
  description = "OTEL Collector endpoint for team members (Tailscale required)"
  value       = "http://${var.instance_name}:4317"
}

output "emergency_ssh" {
  description = "Emergency SSH command (without Tailscale)"
  value       = "gcloud compute ssh ${var.instance_name} --zone=${var.zone}"
}

output "claude_settings_json" {
  description = "Contents of .claude/settings.json to add to target repositories"
  value       = <<-EOT

    Add this to .claude/settings.json in each target repository:

    {
      "env": {
        "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
        "OTEL_METRICS_EXPORTER": "otlp",
        "OTEL_LOGS_EXPORTER": "otlp",
        "OTEL_EXPORTER_OTLP_PROTOCOL": "grpc",
        "OTEL_EXPORTER_OTLP_ENDPOINT": "http://${var.instance_name}:4317",
        "OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE": "cumulative",
        "OTEL_LOG_TOOL_DETAILS": "1",
        "OTEL_LOG_USER_PROMPTS": "1",
        "OTEL_METRICS_INCLUDE_VERSION": "true",
        "OTEL_RESOURCE_ATTRIBUTES": "bu.name=<your-bu>,team.name=<your-team>,project.name=<your-project>"
      }
    }

    Then each member runs: /path/to/cc-analyzer/setup-member.sh
  EOT
}
