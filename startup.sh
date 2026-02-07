#!/bin/bash
set -euo pipefail

WORK_DIR="/opt/cc-dashboard"
GRAFANA_ADMIN_PASSWORD="${grafana_admin_password}"

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
  # Reduce swappiness - only use swap when necessary
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
# 3. Create working directory and config files
# ============================================================
mkdir -p "$WORK_DIR"
mkdir -p "$WORK_DIR/grafana/provisioning/datasources"
mkdir -p "$WORK_DIR/grafana/provisioning/dashboards"
mkdir -p "$WORK_DIR/data/victoriametrics"
mkdir -p "$WORK_DIR/data/victorialogs"
mkdir -p "$WORK_DIR/data/grafana"

# ---- OTEL Collector config ----
cat > "$WORK_DIR/otel-collector-config.yaml" << 'OTELEOF'
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: "0.0.0.0:4317"

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024

exporters:
  # Metrics -> VictoriaMetrics (Prometheus remote write)
  prometheusremotewrite:
    endpoint: "http://victoriametrics:8428/api/v1/write"
    tls:
      insecure: true

  # Logs -> VictoriaLogs (OpenTelemetry native)
  otlphttp/victorialogs:
    endpoint: "http://victorialogs:9428/insert/opentelemetry"
    tls:
      insecure: true

  # Debug output (optional, for troubleshooting)
  debug:
    verbosity: basic

service:
  pipelines:
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheusremotewrite]
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlphttp/victorialogs]
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [debug]
OTELEOF

# ---- Docker Compose ----
cat > "$WORK_DIR/docker-compose.yml" << COMPOSEEOF
services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    container_name: otel-collector
    restart: always
    ports:
      - "4317:4317"
    volumes:
      - ./otel-collector-config.yaml:/etc/otelcol-contrib/config.yaml:ro
    deploy:
      resources:
        limits:
          memory: 128m
    depends_on:
      - victoriametrics
      - victorialogs

  victoriametrics:
    image: victoriametrics/victoria-metrics:latest
    container_name: victoriametrics
    restart: always
    ports:
      - "8428:8428"
    volumes:
      - ./data/victoriametrics:/storage
    command:
      - "--storageDataPath=/storage"
      - "--httpListenAddr=:8428"
      - "--retentionPeriod=365d"
      - "--memory.allowedPercent=60"
    deploy:
      resources:
        limits:
          memory: 192m

  victorialogs:
    image: victoriametrics/victoria-logs:latest
    container_name: victorialogs
    restart: always
    ports:
      - "9428:9428"
    volumes:
      - ./data/victorialogs:/vlogs
    command:
      - "--storageDataPath=/vlogs"
      - "--httpListenAddr=:9428"
      - "--retentionPeriod=90d"
    deploy:
      resources:
        limits:
          memory: 192m

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: always
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD
      - GF_SECURITY_ADMIN_USER=admin
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_INSTALL_PLUGINS=victoriametrics-datasource,victoriametrics-logs-datasource
    volumes:
      - ./data/grafana:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
    deploy:
      resources:
        limits:
          memory: 256m
    depends_on:
      - victoriametrics
      - victorialogs
COMPOSEEOF

# ---- Grafana datasource provisioning ----
cat > "$WORK_DIR/grafana/provisioning/datasources/datasources.yml" << 'DSEOF'
apiVersion: 1

datasources:
  - name: VictoriaMetrics
    type: prometheus
    access: proxy
    url: http://victoriametrics:8428
    isDefault: true
    editable: true

  - name: VictoriaLogs
    type: victoriametrics-logs-datasource
    access: proxy
    url: http://victorialogs:9428
    editable: true
DSEOF

# ---- Grafana dashboard provisioning ----
cat > "$WORK_DIR/grafana/provisioning/dashboards/dashboards.yml" << 'DBEOF'
apiVersion: 1

providers:
  - name: default
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /etc/grafana/provisioning/dashboards
      foldersFromFilesStructure: false
DBEOF

# ---- Fix permissions ----
chown -R 472:472 "$WORK_DIR/data/grafana"  # Grafana runs as uid 472

# ============================================================
# 4. Start all services
# ============================================================
echo ">>> Starting services..."
cd "$WORK_DIR"
docker compose pull
docker compose up -d

echo ">>> Setup complete!"
echo ">>> Grafana: http://$(curl -s ifconfig.me):3000"
echo ">>> OTEL endpoint: http://$(curl -s ifconfig.me):4317"
