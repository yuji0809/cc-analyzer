---
name: documentation-check
description: "cc-analyzer プロジェクトのドキュメントとインフラコードの整合性チェック"
tags: ["documentation", "terraform", "consistency"]
---

# ドキュメントチェック スキル

## このプロジェクトのドキュメント構成

```
cc-analyzer/
  ├── README.md        # セットアップ手順・運用ガイド（メンバー向け）
  ├── DESIGN.md        # 設計書・アーキテクチャ詳細（開発者向け）
  └── infra/
      └── terraform.tfvars.example  # Terraform 設定例
```

## ドキュメント更新が必要になるタイミング

### Terraform 変更時

| 変更内容 | 更新先 |
|---------|--------|
| infra/variables.tf に変数追加 | infra/terraform.tfvars.example, DESIGN.md |
| infra/outputs.tf の環境変数変更 | README.md, DESIGN.md |
| infra/gce.tf のマシンタイプ・リージョン変更 | DESIGN.md (Section 5) |

### Docker / サービス変更時

| 変更内容 | 更新先 |
|---------|--------|
| infra/docker-compose.yml にサービス追加 | DESIGN.md (アーキテクチャ図, コンポーネント表, メモリ配分) |
| infra/docker-compose.yml のポート変更 | DESIGN.md, infra/outputs.tf, README.md |
| infra/otel-collector-config.yaml 変更 | DESIGN.md (Section 3.1) |
| Grafana ダッシュボード追加 | infra/gce.tf, infra/startup.sh |

### Grafana プロビジョニング変更時

| 変更内容 | 更新先 |
|---------|--------|
| datasources.yml に DS 追加 | infra/gce.tf, infra/startup.sh, DESIGN.md |
| ダッシュボード JSON 追加/変更 | infra/gce.tf, infra/startup.sh |
| dashboards.yml のパス変更 | infra/startup.sh |

## 整合性チェック手順

### Step 1: 変数の同期チェック

infra/variables.tf の全変数が以下に反映されているか確認：

```bash
# variables.tf の変数一覧
grep 'variable "' infra/variables.tf

# terraform.tfvars.example の変数一覧
grep -E '^\w' infra/terraform.tfvars.example

# gce.tf の templatefile 変数
grep -A 20 'templatefile(' infra/gce.tf
```

### Step 2: 環境変数の同期チェック

3箇所の環境変数が一致しているか確認：

```bash
# outputs.tf
grep 'export ' infra/outputs.tf

# README.md
grep 'export ' README.md

# DESIGN.md
grep 'export ' DESIGN.md
```

### Step 3: ポート番号の一貫性チェック

```bash
# docker-compose.yml のポート
grep -E '^\s+- "[0-9]+:[0-9]+"' infra/docker-compose.yml

# DESIGN.md のポート記載
grep -E ':[0-9]{4}' DESIGN.md

# otel-collector-config.yaml のエンドポイント
grep 'endpoint' infra/otel-collector-config.yaml
```

### Step 4: Grafana プロビジョニングチェック

```bash
# datasources.yml の uid
grep 'uid:' infra/grafana/provisioning/datasources/datasources.yml

# ダッシュボード JSON の datasource uid 参照
grep -o '"uid": "[^"]*"' infra/grafana/provisioning/dashboards/team-dashboard.json | sort -u

# startup.sh で書き出しているファイル
grep 'cat >' infra/startup.sh
```

### Step 5: DESIGN.md 構造チェック

```bash
# セクション番号の一覧（重複・飛びがないか目視確認）
grep -E '^#{2,3} [0-9]' DESIGN.md
```

## コミット前チェックリスト

- [ ] infra/variables.tf を変更した → infra/terraform.tfvars.example を確認
- [ ] infra/outputs.tf の環境変数を変更した → README.md と DESIGN.md を確認
- [ ] infra/docker-compose.yml を変更した → DESIGN.md のアーキテクチャ図とメモリ配分を確認
- [ ] 新しいファイルを追加した → infra/gce.tf の templatefile と infra/startup.sh を確認
- [ ] ポート番号を変更した → infra/docker-compose.yml, DESIGN.md, infra/outputs.tf を確認
- [ ] Grafana プロビジョニングを変更した → datasource uid の整合性を確認
- [ ] DESIGN.md を編集した → セクション番号の連番を確認
