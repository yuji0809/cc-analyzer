output "instance_ip" {
  description = "Static IP address of the dashboard server"
  value       = google_compute_address.dashboard.address
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${google_compute_address.dashboard.address}:3000"
}

output "otel_endpoint" {
  description = "OTEL Collector gRPC endpoint for team members"
  value       = "http://${google_compute_address.dashboard.address}:4317"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh ${var.ssh_user}@${google_compute_address.dashboard.address}"
}

output "member_env_vars" {
  description = "Environment variables for team members to add to .zshrc/.bashrc"
  value       = <<-EOT

    # === Claude Code Team Dashboard ===
    export CLAUDE_CODE_ENABLE_TELEMETRY=1
    export OTEL_METRICS_EXPORTER=otlp
    export OTEL_LOGS_EXPORTER=otlp
    export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
    export OTEL_EXPORTER_OTLP_ENDPOINT=http://${google_compute_address.dashboard.address}:4317
    export OTEL_LOG_TOOL_DETAILS=1
  EOT
}
