#!/bin/bash
set -euo pipefail

WORK_DIR="/opt/cc-analyzer"

# ============================================================
# 1. Swap setup (critical for e2-micro 1GB RAM)
# ============================================================
if [ ! -f /swapfile ]; then
  echo ">>> Setting up 2GB swap..."
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo 'vm.swappiness=10' >> /etc/sysctl.conf
  sysctl -p
fi

# ============================================================
# 2. Install Docker
# ============================================================
if ! command -v docker &>/dev/null; then
  echo ">>> Installing Docker..."
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl enable docker
  systemctl start docker
fi

if ! command -v jq &>/dev/null; then
  apt-get update -y
  apt-get install -y jq
fi

# ============================================================
# 3. Fetch secrets from Secret Manager
# ============================================================
echo ">>> Fetching secrets from Secret Manager..."
SM_TOKEN=$(curl -sf -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
  | jq -r '.access_token')

fetch_secret() {
  curl -sf -H "Authorization: Bearer $SM_TOKEN" \
    "https://secretmanager.googleapis.com/v1/projects/${project_id}/secrets/$1/versions/latest:access" \
    | jq -r '.payload.data' | base64 -d
}

GRAFANA_ADMIN_PASSWORD=$(fetch_secret "cc-analyzer-grafana-admin-password")
TAILSCALE_AUTH_KEY=$(fetch_secret "cc-analyzer-tailscale-auth-key")
GOOGLE_OAUTH_CLIENT_SECRET=$(fetch_secret "cc-analyzer-google-oauth-client-secret")
echo ">>> Secrets fetched successfully"

# ============================================================
# 4. Install & start Tailscale
# ============================================================
if ! command -v tailscale &>/dev/null; then
  echo ">>> Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
fi

if ! tailscale status &>/dev/null; then
  echo ">>> Starting Tailscale..."
  tailscale up --authkey="$TAILSCALE_AUTH_KEY" --hostname=${instance_name}
fi

# Get Tailscale FQDN (e.g. cc-analyzer.tail12345.ts.net)
TAILSCALE_FQDN=$(tailscale status --json | jq -r '.Self.DNSName' | sed 's/\.$//')
echo ">>> Tailscale FQDN: $TAILSCALE_FQDN"

# Enable HTTPS reverse proxy for Grafana
echo ">>> Enabling Tailscale HTTPS serve..."
tailscale serve --bg --https=443 http://localhost:3000

# ============================================================
# 5. Deploy config files
# ============================================================
mkdir -p "$WORK_DIR/grafana/provisioning/datasources"
mkdir -p "$WORK_DIR/grafana/provisioning/dashboards"
mkdir -p "$WORK_DIR/data/victoriametrics"
mkdir -p "$WORK_DIR/data/victorialogs"
mkdir -p "$WORK_DIR/data/grafana"

cat > "$WORK_DIR/docker-compose.yml" << 'EOF'
${docker_compose}
EOF

cat > "$WORK_DIR/otel-collector-config.yaml" << 'EOF'
${otel_collector_config}
EOF

cat > "$WORK_DIR/grafana/provisioning/datasources/datasources.yml" << 'EOF'
${grafana_datasources}
EOF

cat > "$WORK_DIR/grafana/provisioning/dashboards/dashboards.yml" << 'EOF'
${grafana_dashboards}
EOF

cat > "$WORK_DIR/grafana/provisioning/dashboards/team-template.json" << 'EOF'
${grafana_team_template}
EOF

# Inject credentials into docker-compose.yml
sed -i "s|\$${GRAFANA_ADMIN_USER:-admin}|${grafana_admin_user}|" "$WORK_DIR/docker-compose.yml"
sed -i "s|\$${GRAFANA_ADMIN_PASSWORD:-admin}|$GRAFANA_ADMIN_PASSWORD|" "$WORK_DIR/docker-compose.yml"
sed -i "s|__GRAFANA_FQDN__|$TAILSCALE_FQDN|" "$WORK_DIR/docker-compose.yml"
sed -i "s|__GOOGLE_OAUTH_CLIENT_ID__|${google_oauth_client_id}|" "$WORK_DIR/docker-compose.yml"
sed -i "s|__GOOGLE_OAUTH_CLIENT_SECRET__|$GOOGLE_OAUTH_CLIENT_SECRET|" "$WORK_DIR/docker-compose.yml"
sed -i "s|__GOOGLE_OAUTH_ALLOWED_DOMAIN__|${google_oauth_allowed_domain}|" "$WORK_DIR/docker-compose.yml"

chown -R 472:472 "$WORK_DIR/data/grafana"

# ============================================================
# 6. Start all services
# ============================================================
echo ">>> Starting services..."
cd "$WORK_DIR"
docker compose pull
docker compose up -d

echo ">>> Setup complete!"
echo ">>> Tailscale IP: $(tailscale ip -4)"
echo ">>> Tailscale FQDN: $TAILSCALE_FQDN"
echo ">>> Grafana: https://$TAILSCALE_FQDN (HTTPS via Tailscale)"
echo ">>> OTEL endpoint: http://cc-analyzer:4317"
