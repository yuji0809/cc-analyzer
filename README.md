# Claude Code Team Dashboard

チームのClaude Code活用状況を可視化するダッシュボード。OpenTelemetryで収集したテレメトリをVictoriaMetrics + VictoriaLogs + Grafanaで可視化する。既存のテレメトリだけでは情報が不十分な項目は、Hooks（PreToolUse 等）で補足データを作成し、VictoriaLogs に送信して Grafana で同じダッシュボードから見られるようにしている。

## アーキテクチャ

```
メンバーのPC (Claude Code + Tailscale)
  │ OTLP/gRPC via Tailscale VPN
  ▼
GCE e2-micro (Always Free) + Tailscale (hostname: cc-analyzer)
  ├── OTEL Collector   :4317  ← テレメトリ受信 (Tailscale内のみ)
  ├── VictoriaMetrics  :8428  ← メトリクス保存 (1年)
  ├── VictoriaLogs     :9428  ← ログ保存 (90日)
  └── Grafana          :443   ← ダッシュボード (Tailscale HTTPS + Google OAuth)
```

全ての通信は Tailscale VPN 経由。MagicDNS により `cc-analyzer` のホスト名でアクセスできる。

**テレメトリ + Hooks:** 標準テレメトリ（OTLP）は OTEL Collector 経由で受信。テレメトリに含まれない情報（例: Read で読んだファイルパス）は Hooks スクリプトで取得し、VictoriaLogs の JSON Lines API に直接送信し、Grafana で可視化する。

## 前提条件

- GCPプロジェクト（課金有効化済み）
- Terraform >= 1.5
- [Tailscale](https://tailscale.com/) アカウント（無料枠: 100台）
- [jq](https://jqlang.github.io/jq/) — Hooks スクリプトで使用（`brew install jq`）

## セットアップ

### 1. Tailscale の準備

1. https://login.tailscale.com でアカウント作成
2. https://login.tailscale.com/admin/settings/keys で Auth Key を生成
   - Reusable: ON（VMの再構築時に再利用可能）
   - Expiration: 任意
3. MagicDNS が有効であることを確認 (https://login.tailscale.com/admin/dns)
4. **HTTPS Certificates を有効化** (同じ DNS 設定ページ)
   - `tailscale serve --https` による自動証明書取得に必要
5. tailnet 名を控えておく（DNS ページに表示、例: `tail12345.ts.net`）
6. Auth Key を控えておく

### 1.5. Google OAuth の準備

1. [GCP Console](https://console.cloud.google.com/) > APIs & Services > Credentials
2. Create OAuth Client ID (Web application)
3. 承認済みのリダイレクト URI: `https://cc-analyzer.<tailnet>.ts.net/login/google`
   - `<tailnet>` は手順 1-5 で控えた tailnet 名
   - 「承認済みの JavaScript 生成元」は空欄でOK（Grafana はサーバーサイド OAuth のため不要）
4. Client ID と Client Secret を控えておく

### 2. Terraform でインフラ構築

```bash
cd infra

# 設定ファイルを作成
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars を編集（project_id, grafana_admin_password, tailscale_auth_key, google_oauth_*）

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
3. **対象リポジトリにテレメトリ設定を追加**:

リポジトリ管理者が `.claude/settings.json` をコミット（リポジトリごとに1回）:

```json
{
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "otlp",
    "OTEL_LOGS_EXPORTER": "otlp",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "grpc",
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://cc-analyzer:4317",
    "OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE": "cumulative",
    "OTEL_LOG_TOOL_DETAILS": "1",
    "OTEL_LOG_USER_PROMPTS": "1",
    "OTEL_METRICS_INCLUDE_VERSION": "true",
    "OTEL_RESOURCE_ATTRIBUTES": "project.name=REPO_NAME"
  }
}
```

各メンバーがセットアップスクリプトを実行（対象リポジトリのルートで）:

```bash
/path/to/cc-analyzer/setup-member.sh
```

> `.claude/settings.local.json` が作成され、`user.name` がテレメトリに含まれるようになる。
> `.zshrc` への設定は不要。テレメトリは設定があるリポジトリのセッションだけに限定される。
>
> **重要**: このスクリプトを実行しないと、ダッシュボードの「User」フィルターでユーザーを識別できません。必ず各メンバーが実行してください。

### 5. ダッシュボードにアクセス

```
URL:  https://cc-analyzer.<tailnet>.ts.net
認証: Google OAuth（許可ドメインのGoogleアカウントでログイン）
管理者: admin / terraform.tfvars で設定したパスワード
```

## ローカル開発

Docker Compose でローカルでもダッシュボードを起動できる。

```bash
cd infra
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

GUIで作成したダッシュボードはJSON形式でエクスポートできる。`infra/grafana/provisioning/dashboards/` に保存すれば、再構築時に自動復元される。

### 破棄

```bash
cd infra
terraform destroy
```

## リファレンス

- [Claude Code テレメトリ公式ドキュメント](https://code.claude.com/docs/ja/monitoring-usage) — OpenTelemetry の有効化・設定・環境変数の公式リファレンス。テレメトリ関連で困ったらまずここを参照。
- [DESIGN.md](./DESIGN.md) — 本プロジェクトの詳細設計
- [DASHBOARD.md](./DASHBOARD.md) — ダッシュボードで見れる情報一覧
