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

# ============================================================
# 3. Install Tailscale
# ============================================================
if ! command -v tailscale &>/dev/null; then
  echo ">>> Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
fi

if ! tailscale status &>/dev/null; then
  echo ">>> Starting Tailscale..."
  tailscale up --authkey="${tailscale_auth_key}" --hostname=cc-analyzer
fi

# ============================================================
# 4. Deploy config files
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

cat > "$WORK_DIR/grafana/provisioning/dashboards/team-dashboard.json" << 'EOF'
${grafana_team_dashboard}
EOF

# Inject Grafana admin credentials into docker-compose.yml
sed -i "s|\$${GRAFANA_ADMIN_USER:-admin}|${grafana_admin_user}|" "$WORK_DIR/docker-compose.yml"
sed -i "s|\$${GRAFANA_ADMIN_PASSWORD:-admin}|${grafana_admin_password}|" "$WORK_DIR/docker-compose.yml"

chown -R 472:472 "$WORK_DIR/data/grafana"

# ============================================================
# 5. Start all services
# ============================================================
echo ">>> Starting services..."
cd "$WORK_DIR"
docker compose pull
docker compose up -d

echo ">>> Setup complete!"
echo ">>> Tailscale IP: $(tailscale ip -4)"
echo ">>> Grafana: http://cc-analyzer:3000"
echo ">>> OTEL endpoint: http://cc-analyzer:4317"
