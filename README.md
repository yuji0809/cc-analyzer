# Claude Code Team Dashboard

チームのClaude Code活用状況を可視化するダッシュボード。OpenTelemetryで収集したテレメトリをVictoriaMetrics + VictoriaLogs + Grafanaで可視化する。

## アーキテクチャ

```
メンバーのPC (Claude Code + Tailscale)
  │ OTLP/gRPC via Tailscale VPN
  ▼
GCE e2-micro (Always Free) + Tailscale (hostname: cc-analyzer)
  ├── OTEL Collector   :4317  ← テレメトリ受信 (Tailscale内のみ)
  ├── VictoriaMetrics  :8428  ← メトリクス保存 (1年)
  ├── VictoriaLogs     :9428  ← ログ保存 (90日)
  └── Grafana          :3000  ← ダッシュボード (Tailscale内のみ)
```

全ての通信は Tailscale VPN 経由。MagicDNS により `cc-analyzer` のホスト名でアクセスできる。

## 前提条件

- GCPプロジェクト（課金有効化済み）
- Terraform >= 1.5
- [Tailscale](https://tailscale.com/) アカウント（無料枠: 100台）

## セットアップ

### 1. Tailscale の準備

1. https://login.tailscale.com でアカウント作成
2. https://login.tailscale.com/admin/settings/keys で Auth Key を生成
   - Reusable: ON（VMの再構築時に再利用可能）
   - Expiration: 任意
3. MagicDNS が有効であることを確認 (https://login.tailscale.com/admin/dns)
4. Auth Key を控えておく

### 2. Terraform でインフラ構築

```bash
# 設定ファイルを作成
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars を編集（project_id, grafana_admin_password, tailscale_auth_key）

# デプロイ
terraform init
terraform plan
terraform apply
```

### 3. 起動確認

`terraform apply` 完了後、startup script が自動実行される（3-5分）。

```bash
# Tailscale Admin Console で cc-analyzer が接続済みか確認
# https://login.tailscale.com/admin/machines

# SSH接続して状態確認 (Tailscale経由)
ssh ubuntu@cc-analyzer

# コンテナの稼働確認
sudo docker ps
```

### 4. メンバーのセットアップ

各メンバーは以下を行う:

1. **Tailscale をインストール**: https://tailscale.com/download
2. **同じ Tailnet にログイン**
3. **環境変数を設定** (.zshrc / .bashrc に追記):

```bash
# === Claude Code Team Dashboard ===
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT=http://cc-analyzer:4317
export OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative
export OTEL_LOG_TOOL_DETAILS=1
export OTEL_RESOURCE_ATTRIBUTES="user.name=YOUR_NAME"  # ダッシュボードでの表示名
```

### 5. ダッシュボードにアクセス

```
URL:  http://cc-analyzer:3000
User: admin
Pass: terraform.tfvars で設定したパスワード
```

## ローカル開発

Docker Compose でローカルでもダッシュボードを起動できる。

```bash
GRAFANA_ADMIN_PASSWORD=admin docker compose up
```

- Grafana: http://localhost:3000
- OTEL: localhost:4317

## 運用

### メンテナンス

```bash
# SSH接続 (Tailscale MagicDNS)
ssh ubuntu@cc-analyzer

# サービス再起動
cd /opt/cc-analyzer
sudo docker compose restart

# ログ確認
sudo docker compose logs -f --tail=50

# ディスク使用量確認
df -h
sudo du -sh /opt/cc-analyzer/data/*

# 緊急SSH (Tailscale不通時)
gcloud compute ssh cc-analyzer --zone=us-central1-a
```

### ダッシュボードのバックアップ

GUIで作成したダッシュボードはJSON形式でエクスポートできる。`grafana/provisioning/dashboards/` に保存すれば、再構築時に自動復元される。

### 破棄

```bash
terraform destroy
```

## 詳細設計

[DESIGN.md](./DESIGN.md) を参照。
