output "instance_ip" {
  description = "Public IP address (for reference only, services are not exposed)"
  value       = google_compute_address.dashboard.address
}

output "grafana_url" {
  description = "Grafana dashboard URL (Tailscale required)"
  value       = "http://cc-analyzer:3000"
}

output "otel_endpoint" {
  description = "OTEL Collector endpoint for team members (Tailscale required)"
  value       = "http://cc-analyzer:4317"
}

output "emergency_ssh" {
  description = "Emergency SSH command (without Tailscale)"
  value       = "gcloud compute ssh cc-analyzer --zone=${var.zone}"
}

output "member_env_vars" {
  description = "Environment variables for team members"
  value       = <<-EOT

    # === Claude Code Team Dashboard ===
    # Requires: Tailscale connected to the same Tailnet
    export CLAUDE_CODE_ENABLE_TELEMETRY=1
    export OTEL_METRICS_EXPORTER=otlp
    export OTEL_LOGS_EXPORTER=otlp
    export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
    export OTEL_EXPORTER_OTLP_ENDPOINT=http://cc-analyzer:4317
    export OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative
    export OTEL_LOG_TOOL_DETAILS=1
    export OTEL_RESOURCE_ATTRIBUTES="user.name=YOUR_NAME"
  EOT
}
