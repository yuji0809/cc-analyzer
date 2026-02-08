# Terraform 事前チェック

`infra/` ディレクトリで以下のコマンドを順番に実行し、結果をまとめてください。

## 1. terraform fmt -check

フォーマットが正しいか確認。差分がある場合は `terraform fmt` で自動修正してください。

```bash
cd infra && terraform fmt -check -diff
```

差分があった場合:
```bash
cd infra && terraform fmt
```

## 2. terraform validate

構文・参照エラーがないか確認。

```bash
cd infra && terraform validate
```

## 3. terraform plan

実際のインフラとの差分を確認。**apply は実行しないでください。**

```bash
cd infra && terraform plan
```

## 出力フォーマット

各ステップの結果を以下の形式で報告してください：

| ステップ | 結果 | 詳細 |
|---------|------|------|
| fmt     | OK / 修正済み | 修正したファイルがあれば列挙 |
| validate | OK / NG | エラーがあれば内容を記載 |
| plan    | No changes / N to add, N to change, N to destroy | 差分の概要 |

plan で差分がある場合は、変更内容の概要を箇条書きで説明してください。
apply して問題ないかの判断材料を提供してください。
