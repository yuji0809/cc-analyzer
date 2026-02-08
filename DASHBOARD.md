# ダッシュボードで見れる情報一覧

## 現在のダッシュボード（テレメトリ）

リアルタイムで自動収集されるデータ。メンバーは通常通り Claude Code を使うだけで蓄積される。

### メトリクス（時系列グラフ）

| カテゴリ | 指標 | フィルター | 可視化 |
|---------|------|-----------|--------|
| セッション | セッション数 | ユーザー別、プロジェクト別 | stat + 時系列バー |
| 時間 | アクティブコーディング時間 | ユーザー別 | stat + 時系列バー |
| コスト | API推定コスト (USD) | ユーザー別、モデル別 | stat + 時系列ライン |
| トークン | トークン消費量 | タイプ別 (input / output / cacheRead / cacheCreation) | stat + 時系列ライン |
| コード変更 | 追加行数 / 削除行数 | タイプ別 | 時系列バー |
| Git | コミット数、PR数 | ユーザー別 | 時系列バー |
| Edit/Write 判断 | Accept/Reject 率 | ツール別・言語別 | 時系列バー |

### ログ（イベントビューア）

| カテゴリ | 見れる内容 | 条件 |
|---------|-----------|------|
| ツール実行 | どのツール (Edit, Bash, Read等) がいつ実行されたか、成功/失敗、所要時間 | - |
| MCP呼び出し | どの MCP サーバー・ツールが使われたか | `OTEL_LOG_TOOL_DETAILS=1` |
| スキル利用 | どのスキルが使われたか | `OTEL_LOG_TOOL_DETAILS=1` |

### ダッシュボード化していないが取得できているデータ

以下はテレメトリとして収集済みだが、まだ Grafana パネルを作成していないもの。必要に応じてパネルを追加できる。

| データ | ソース | 備考 |
|-------|--------|------|
| API リクエスト詳細 | ログ: `claude_code.api_request` | モデル、レイテンシ、トークン数 |
| API エラー | ログ: `claude_code.api_error` | エラー内容、ステータスコード |
| プロンプト長 | ログ: `claude_code.user_prompt` | 文字数のみ（内容は `OTEL_LOG_USER_PROMPTS=1` で取得可） |

---

## /insights を追加すると見れるようになるもの

`/insights` は Claude Code が内部で集計するセッションサマリー。テレメトリでは取得できない**定性データ**が含まれる。現在は未実装（将来フェーズ）。

| カテゴリ | データ | 活用例 | テレメトリでは取れない理由 |
|---------|-------|--------|----------------------|
| セッション目標 | 13分類 (debug_investigate, implement_feature, refactor, write_tests 等) | 「チームはデバッグに何%の時間を使っているか」 | Claude が内部で分類するデータで OTEL に含まれない |
| 成果達成度 | 5段階 (not_achieved → fully_achieved) | 「セッションの何%で目標を達成できているか」の推移 | セッション終了時の内部評価 |
| 満足度 | 6段階 (frustrated → happy) | 「ユーザー体験が改善しているか」のトレンド | 同上 |
| フリクション | 12分類 (misunderstood_request, buggy_code, slow_response 等) | 「どんな問題が多いか」→ スキル改善の材料 | セッション中の摩擦を内部判定 |
| プログラミング言語 | ファイル拡張子ベースの推定 | 「チームは何の言語で Claude Code を使っているか」 | テレメトリにはファイル拡張子情報がない |
| 先頭プロンプト | セッション開始時の指示内容 | 「どんなタスクに Claude Code を使っているか」の定性分析 | プロンプト内容はデフォルトで送信されない |

### テレメトリと /insights の使い分け

```
テレメトリ（現在のダッシュボード）:
  → "何を" "どれだけ" 使ったか（定量データ）
  → ツール使用回数、トークン消費量、コスト、コード変更量

/insights:
  → "うまくいったか" "何に困ったか"（定性データ）
  → 成果達成度、満足度、フリクション、セッション目標
```

テレメトリだけでは「Edit ツールが100回使われた」はわかるが、「そのセッションでユーザーが満足したか」はわからない。/insights が加わると PDCA の「Check」の精度が上がる。

### /insights 実装に必要なもの

```
1. メンバーが Claude Code で /insights を実行
2. 出力 HTML から JSON を抽出するスクリプト (extract-metrics.js)
3. JSON を VictoriaMetrics に HTTP push (/api/v1/import)
4. Grafana に /insights 用パネルを追加
```

---

## テレメトリの技術詳細

### メトリクス一覧（8種類）

Claude Code が OTEL メトリクスプロトコルで送信する全メトリクス。

| OTEL メトリクス名 | Prometheus 名 | 単位 | 属性 |
|------------------|--------------|------|------|
| `claude_code.session.count` | `claude_code_session_count_total` | count | - |
| `claude_code.active_time.total` | `claude_code_active_time_total_seconds_total` | seconds | - |
| `claude_code.cost.usage` | `claude_code_cost_usage_total` | USD | `model` |
| `claude_code.token.usage` | `claude_code_token_usage_total` | tokens | `type` (input/output/cacheRead/cacheCreation), `model` |
| `claude_code.lines_of_code.count` | `claude_code_lines_of_code_count_total` | count | `type` (added/removed) |
| `claude_code.commit.count` | `claude_code_commit_count_total` | count | - |
| `claude_code.pull_request.count` | `claude_code_pull_request_count_total` | count | - |
| `claude_code.code_edit_tool.decision` | `claude_code_code_edit_tool_decision_total` | count | `tool`, `decision` (accept/reject), `language` |

### ログイベント一覧（5種類）

Claude Code が OTEL ログプロトコルで送信する全イベント。

| イベント名 | 内容 | 主な属性 |
|-----------|------|---------|
| `claude_code.tool_result` | ツール実行結果 | `tool_name`, `success`, `duration_ms`, `tool_parameters`* |
| `claude_code.user_prompt` | ユーザープロンプト | `prompt_length`, `prompt`** |
| `claude_code.api_request` | API リクエスト | `model`, `cost_usd`, `duration_ms`, `input_tokens`, `output_tokens` |
| `claude_code.api_error` | API エラー | `model`, `error`, `status_code` |
| `claude_code.tool_decision` | ツール許可判断 | `tool_name`, `decision`, `source` |

\* `tool_parameters` は JSON 文字列。`OTEL_LOG_TOOL_DETAILS=1` 設定時に MCP サーバー名 (`mcp_server_name`)、スキル名 (`skill_name`) 等を含む。
\*\* `prompt` は `OTEL_LOG_USER_PROMPTS=1` 設定時のみ含まれる。

### 共通属性

全てのメトリクス・イベントに付与されるリソース属性。

| 属性 | 値 |
|------|-----|
| `service.name` | `claude-code` |
| `os.type` | `darwin` / `linux` / `windows` |
| `host.arch` | `amd64` / `arm64` |
| `terminal.type` | `iTerm.app` / `vscode` / `cursor` 等 |
| `user.name` | `OTEL_RESOURCE_ATTRIBUTES` で設定した値 |
| `project.name` | `OTEL_RESOURCE_ATTRIBUTES` で設定した値 |
