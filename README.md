# Claude Code Team Dashboard

チームのClaude Code活用状況を可視化するダッシュボード。OpenTelemetryで収集したテレメトリをVictoriaMetrics + VictoriaLogs + Grafanaで可視化する。

## アーキテクチャ

```
メンバーのPC (Claude Code)
  │ OTLP/gRPC
  ▼
GCE e2-micro (Always Free)
  ├── OTEL Collector   :4317  ← テレメトリ受信
  ├── VictoriaMetrics  :8428  ← メトリクス保存 (1年)
  ├── VictoriaLogs     :9428  ← ログ保存 (90日)
  └── Grafana          :3000  ← ダッシュボード
```

## セットアップ

### 前提条件

- GCPプロジェクト（課金有効化済み）
- Terraform >= 1.5
- SSH キーペア

### 1. Terraform でインフラ構築

```bash
cd terraform

# 設定ファイルを作成
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars を編集（project_id, パスワード等）

# デプロイ
terraform init
terraform plan
terraform apply
```

### 2. 起動確認

`terraform apply` 完了後、startup script が自動実行される（3-5分）。

```bash
# SSH接続して状態確認
ssh ubuntu@$(terraform output -raw instance_ip)

# コンテナの稼働確認
sudo docker ps

# ログ確認
sudo docker compose -f /opt/cc-dashboard/docker-compose.yml logs
```

### 3. メンバーのセットアップ

```bash
# セットアップスクリプトのIPを更新
DASHBOARD_IP=$(terraform output -raw instance_ip)
sed -i "s/__REPLACE_WITH_TERRAFORM_OUTPUT__/$DASHBOARD_IP/" ../scripts/setup-member.sh

# メンバーにスクリプトを配布して実行してもらう
# または手動で以下を .zshrc/.bashrc に追記:
terraform output -raw member_env_vars
```

### 4. ダッシュボードにアクセス

```
URL:  terraform output -raw grafana_url
User: admin
Pass: terraform.tfvars で設定したパスワード
```

## 運用

### ダッシュボードのバックアップ

GUIで作成したダッシュボードはJSON形式でエクスポートできる。`docker/grafana/provisioning/dashboards/` に保存すれば、再構築時に自動復元される。

### メンテナンス

```bash
# SSH接続
ssh ubuntu@$(terraform output -raw instance_ip)

# サービス再起動
cd /opt/cc-dashboard
sudo docker compose restart

# ログ確認
sudo docker compose logs -f --tail=50

# ディスク使用量確認
df -h
sudo du -sh /opt/cc-dashboard/data/*
```

### 破棄

```bash
cd terraform
terraform destroy
```

## 詳細設計

[DESIGN.md](./DESIGN.md) を参照。
