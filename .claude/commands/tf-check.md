# Terraform 事前チェック

Task ツールで Terraform チェック用エージェントを `subagent_type: "Bash"` として起動し、`infra/` ディレクトリで以下の3ステップを順番に実行してください。

## エージェントへの指示

1. `terraform fmt -check -diff` を実行。差分がある場合は `terraform fmt` で自動修正
2. `terraform validate` を実行
3. `terraform plan` を実行（**apply は実行しない**）

## 出力フォーマット

エージェントの結果を受け取ったら、以下の形式でユーザーに報告してください：

| ステップ | 結果 | 詳細 |
|---------|------|------|
| fmt     | OK / 修正済み | 修正したファイルがあれば列挙 |
| validate | OK / NG | エラーがあれば内容を記載 |
| plan    | No changes / N to add, N to change, N to destroy | 差分の概要 |

plan で差分がある場合は、変更内容の概要を箇条書きで説明してください。
apply して問題ないかの判断材料を提供してください。
