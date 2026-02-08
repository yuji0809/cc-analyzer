# ドキュメント整合性チェック

以下のチェックを実行し、結果をまとめてください。

## 1. infra/variables.tf と infra/terraform.tfvars.example の同期

- infra/variables.tf に定義されている全変数が infra/terraform.tfvars.example に記載されているか
- default 値のない変数（必須変数）が infra/terraform.tfvars.example で明示されているか

## 2. infra/outputs.tf と README.md の環境変数の同期

- infra/outputs.tf の `member_env_vars` に含まれる環境変数が README.md のメンバーセットアップセクションと一致しているか
- 新しい環境変数が追加された場合、両方に反映されているか

## 3. DESIGN.md とコードの整合性

- DESIGN.md のアーキテクチャ図のポート番号が infra/docker-compose.yml と一致しているか
- DESIGN.md のコンポーネント説明（メモリ上限、保持期間等）が infra/docker-compose.yml / infra/otel-collector-config.yaml と一致しているか
- DESIGN.md のセクション番号が連番になっているか（重複・飛びがないか）
- DESIGN.md のリポジトリ構成図が実際のファイル構成と一致しているか

## 4. infra/gce.tf と infra/startup.sh の同期

- infra/gce.tf の templatefile() に渡している変数が infra/startup.sh 内で全て使用されているか
- infra/startup.sh で参照しているテンプレート変数が infra/gce.tf で全て定義されているか

## 5. Grafana プロビジョニングの整合性

- dashboards.yml の path 設定とダッシュボードJSONファイルの配置が一致しているか
- datasources.yml の uid がダッシュボードJSON内の datasource 参照と一致しているか
- infra/startup.sh で全てのプロビジョニングファイルが書き出されているか

## 出力フォーマット

各チェック項目について以下の形式で報告してください：

- OK: 整合性あり
- WARN: 軽微な不整合（推奨修正）
- NG: 修正が必要な不整合（具体的な差分を記載）
