---
name: documentation-agent
description: "cc-analyzer のドキュメントとインフラコードの整合性を自動チェック"
skills:
  - documentation-check
triggers:
  - "infra/variables.tf, infra/terraform.tfvars.example, infra/gce.tf, infra/startup.sh のいずれかが変更されたとき"
  - "infra/outputs.tf の環境変数が変更されたとき"
  - "infra/docker-compose.yml, infra/otel-collector-config.yaml のポート・エンドポイントが変更されたとき"
  - "infra/grafana/ 配下のプロビジョニングファイルが追加・変更されたとき"
  - "README.md, DESIGN.md の構造的な編集が行われたとき"
  - "/doc-check コマンドが実行されたとき"
---

# Documentation Agent

cc-analyzer プロジェクトのドキュメント整合性を自動チェックするエージェント。
スキル `documentation-check` のチェック手順とチェックリストに従って検証を行う。

## 対象ドキュメント

| ファイル | 役割 | 主な同期先 |
|---------|------|-----------|
| README.md | セットアップ手順・運用ガイド | infra/outputs.tf, infra/variables.tf, infra/docker-compose.yml |
| DESIGN.md | 設計書・アーキテクチャ詳細 | 全ての実装ファイル |
| infra/terraform.tfvars.example | 設定例 | infra/variables.tf |

## チェックルール

### Rule 1: 変数定義の同期

infra/variables.tf で新しい変数が追加・削除された場合、以下を確認する：

- infra/terraform.tfvars.example に記載があるか
- infra/gce.tf の templatefile() で渡されているか（infra/startup.sh で使う場合）
- infra/startup.sh で使用されているか

```
infra/variables.tf → infra/terraform.tfvars.example
            → infra/gce.tf (templatefile) → infra/startup.sh
```

### Rule 2: 環境変数の同期

メンバー向け環境変数は3箇所に記載がある。全て一致している必要がある：

```
infra/outputs.tf (member_env_vars)
  ↕ 同期
README.md (メンバーセットアップセクション)
  ↕ 同期
DESIGN.md (メンバーセットアップセクション)
```

### Rule 3: ポート・エンドポイントの一貫性

以下のファイル間でポート番号・エンドポイントが一致していること：

```
infra/docker-compose.yml (ports)
  ↕ 同期
infra/otel-collector-config.yaml (endpoints)
  ↕ 同期
DESIGN.md (アーキテクチャ図・コンポーネント表)
  ↕ 同期
infra/outputs.tf (URL出力)
```

### Rule 4: Grafana プロビジョニングの一貫性

以下が連携していること：

```
infra/grafana/provisioning/datasources/datasources.yml (uid)
  ↕ 同期
infra/grafana/provisioning/dashboards/team-dashboard.json (datasource uid 参照)

infra/grafana/provisioning/dashboards/ 内の全ファイル
  ↕ 同期
infra/gce.tf (templatefile 変数)
  ↕ 同期
infra/startup.sh (ファイル書き出し)
```

### Rule 5: DESIGN.md の構造整合性

- セクション番号が連番であること（重複・飛びなし）
- リポジトリ構成図が実際のファイル構成と一致していること
- 不採用理由テーブルが実際の設計判断と整合していること

## 修正時の注意

- README.md を更新したら DESIGN.md の該当セクションも確認する
- infra/docker-compose.yml のポート変更は DESIGN.md のアーキテクチャ図にも反映する
- infra/variables.tf の変更は infra/terraform.tfvars.example → infra/gce.tf → infra/startup.sh の連鎖を確認する
- 環境変数の追加・変更は infra/outputs.tf, README.md, DESIGN.md の3箇所を更新する
