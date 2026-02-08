# ドキュメント整合性チェック

`documentation-agent` エージェントを Task ツールで起動し、`documentation-check` スキルに従ってドキュメント整合性チェックを実行してください。

## 実行手順

1. Task ツールで `documentation-agent` を `subagent_type: "general-purpose"` として起動する
2. エージェントには以下のプロンプトを渡す:
   - `.claude/agents/documentation-agent.md` と `.claude/skills/documentation-check.md` を読み込む
   - チェックルールとチェック手順に従って全項目を検証する
   - 結果を OK / WARN / NG の形式で報告する

## 出力フォーマット

エージェントの結果を受け取ったら、以下の形式でユーザーに報告してください：

- OK: 整合性あり
- WARN: 軽微な不整合（推奨修正）
- NG: 修正が必要な不整合（具体的な差分を記載）
