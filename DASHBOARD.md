# ダッシュボードで見れる情報一覧

## 現在のダッシュボード（テレメトリ）

リアルタイムで自動収集されるデータ。メンバーは通常通り Claude Code を使うだけで蓄積される。

> **Note:** 「ユーザー別」のフィルター・グラフは、各メンバーが `setup-member.sh` を実行済みの場合のみ機能する。未実行のメンバーのデータは `user.name` 属性なしで記録され、User フィルターに表示されない。

### 1. 概要

セッション数・合計コスト・合計トークン・アクティブ時間の4つの stat パネル。

**わかること:** チーム全体の Claude Code 活用度を一目で把握できる。「今週どれくらい使われたか」「コストは適正か」を瞬時に確認。

**分析例:**
- 週次でコストの推移を追い、予算管理に活用
- アクティブ時間とセッション数の比率で「1セッションあたりの平均作業時間」を推定
- メンバー追加後の利用拡大トレンドを確認

### 2. セッション & アクティビティ

ユーザー別のセッション数とアクティブ時間の時系列バーチャート。

**わかること:** 誰がどれくらい Claude Code を使っているか。活用度の偏りや時間帯の傾向。

**分析例:**
- 特定メンバーの利用が少ない場合、オンボーディング支援やスキル改善の検討材料に
- 曜日・時間帯のパターンから、チームのワークスタイルを把握
- 新規メンバーの立ち上がり（利用開始〜定着）をトラッキング

### 3. トークン & コスト

タイプ別トークン使用量（input/output/cacheRead/cacheCreation）、ユーザー別コスト、モデル別コストの3パネル。

**わかること:** トークンの消費内訳とコスト構造。どのモデルにいくらかかっているか。

**分析例:**
- `cacheRead` の割合が高いほどキャッシュが効いており、コスト効率が良い
- `cacheCreation` が急増していたら、コンテキストの大幅な変更が頻発している可能性
- モデル別コストで Opus vs Sonnet のコスト比率を把握し、モデル選択の最適化を検討
- 特定ユーザーのコストが突出していたら、使い方のヒアリングや改善提案の材料に

### 4. コード変更

コード追加/削除行数、コミット & PR 数、Edit/Write の承認 vs 却下率、言語別判断の4パネル。

**わかること:** Claude Code がどれだけコードを生成・変更しているか。ユーザーがその提案をどの程度受け入れているか。

**分析例:**
- 追加行数 vs 削除行数の比率で「新規開発 vs リファクタリング」の傾向を把握
- Reject 率が高い場合、プロンプトの質やスキル設定の改善が必要なサイン
- 言語別の Accept 率で、Claude Code が得意/不得意な言語を特定
- コミット・PR 数の推移で開発アウトプットへの貢献度を測定

### 5. API パフォーマンス

API リクエストログと API エラーログの2パネル。

**わかること:** 各 API リクエストの詳細（モデル、コスト、レスポンス時間、トークン数、キャッシュ利用状況）と、エラーの発生状況。

**分析例:**
- `duration_ms` が長いリクエストを特定し、パフォーマンスボトルネックを発見
- `cache_read_tokens` / `input_tokens` でリクエスト単位のキャッシュヒット率を計算
- API エラーの `status_code` で 429（レート制限）の頻度を確認し、使用ペースの調整を検討
- `attempt` フィールドでリトライ回数が多いリクエストを特定し、API の安定性を評価

### 6. ツール分析

全ツール実行一覧、ツール失敗ログ、Bash コマンドログの3パネル。

**わかること:** Claude Code がどのツールをどう使っているか。失敗パターンやBashで実行されたコマンドの詳細。

**分析例:**
- ツール失敗ログで頻発するエラーパターンを特定し、権限設定やスキルの改善に活用
- Bash コマンドログで、実行されているコマンドの安全性を監査
- ツール別の使用頻度から、チームの Claude Code 活用パターンを理解（Read 多め＝調査中心、Edit 多め＝実装中心）

### 7. MCP・スキル・エージェント

MCP サーバー呼び出し、スキル & コマンド、エージェント使用状況、カスタムツール一覧の4パネル + **スキル利用頻度**、**MCP ツール利用頻度**の集計テーブル2パネル。

**わかること:** カスタム拡張機能（MCP サーバー、スキル、エージェント）の利用状況と、コマンド別・ツール別の利用回数。

**分析例:**
- スキル利用頻度テーブルで `/doc-check` や `/tf-check` の利用回数を定量化し、チームへの浸透度を測定
- MCP ツール利用頻度テーブルで、サーバー・ツール別の利用回数を把握し、投資対効果を評価
- エージェント（Task ツール）の使用頻度で、複雑なタスクの自動化度合いを把握
- 利用されていないカスタムツールがあれば、廃止や改善を検討

### 8. ツール許可判断ログ

ツール実行の許可/拒否判断のログパネル。

**わかること:** ユーザーがどのツールの実行を許可/拒否したか。判断の source（config/user_permanent/user_temporary 等）。

**分析例:**
- Reject が多いツールを特定し、`settings.json` の `permissions.allow` に追加して UX を改善
- 意図しない拒否パターンがないか確認（フック設定の不備など）
- チーム全体の権限設定の最適化材料に

### 9. ユーザープロンプト

ユーザーが入力したプロンプトの内容と長さのログパネル。

**わかること:** ユーザーが Claude Code にどんなタスクを依頼しているかの実際の内容。

**分析例:**
- よく依頼されるタスクパターンを特定し、カスタムスキルやエージェントとして自動化
- プロンプトの質を分析し、チーム向けのプロンプトガイドラインを作成
- 「こういう使い方もできる」という好事例を発見し、チーム内で共有
- プロンプト長の傾向から、タスクの複雑さの推移を把握

### 10. ファイル読み込み追跡

ファイル読み込みログと .md ファイル読み込みの2パネル。

#### なぜ Hooks が必要か

Claude Code のネイティブテレメトリでは、Read ツールの `tool_result` イベントに `tool_name: "Read"` は記録されるが、**読み込んだファイルパスは送信されない**（組み込みツールの `tool_parameters` は null）。そのため「どのファイルを読んだか」はテレメトリだけでは追跡できない。

これを補完するために Claude Code の **Hooks 機能**（`PreToolUse`）を使い、Read ツール呼び出し時にファイルパスをキャプチャして VictoriaLogs に直接送信する仕組みを導入した。

#### 仕組み

```
Developer PC (Claude Code)
  │ Read ツール呼び出し
  │   → PreToolUse hook 発火（async: true = バックグラウンド実行）
  │     → .claude/hooks/log-file-reads.sh
  │       1. stdin の JSON から file_path, session_id を抽出 (jq)
  │       2. OTEL_RESOURCE_ATTRIBUTES から user.name, project.name を抽出
  │       3. curl で VictoriaLogs に直接 POST
  ▼
cc-analyzer VM (Tailscale VPN 経由)
  └── VictoriaLogs :9428/insert/jsonline
        → Grafana ダッシュボードで可視化
```

**OTEL Collector を経由しない理由:** OTLP/gRPC で curl から送信するには protobuf JSON 形式が必要で複雑。VictoriaLogs の JSON Lines API（`/insert/jsonline`）は HTTP POST で1行 JSON を送るだけのシンプルな API。

#### パフォーマンスへの影響

- **Claude Code の応答速度:** 影響なし。`async: true` により hook はバックグラウンド実行され、Claude Code は hook の完了を待たずに Read ツールを即座に実行する
- **VM のリソース:** 影響なし。1 Read あたり約 200 バイトの JSON 1行。5人 × 50 Read/セッション × 3セッション/日 = 約 750 リクエスト/日。VictoriaLogs のメモリ使用量（~20 MB / 192 MB 上限）に対して誤差レベル
- **ネットワーク障害時:** curl に `--max-time 2` のタイムアウトと `|| true` を設定済み。Tailscale 未接続でも 2 秒で静かに失敗し、Claude Code に影響を与えない

#### 前提条件

- `jq` が必要（`brew install jq`）。hook スクリプト内で JSON パースに使用
- Tailscale 接続中であること（`cc-analyzer:9428` に到達可能な状態）

**わかること:** Claude Code がどのファイルを読んでいるか。特に CLAUDE.md やドキュメント（.md ファイル）がどれだけ参照されているか。

**分析例:**
- `.md` フィルターで CLAUDE.md やカスタムコマンドの .md がどれだけ読まれているかを追跡
- よく読まれるファイルのパターンから、チームの調査・実装スタイルを把握
- `session_id` でセッション単位の読み込みファイル一覧を確認し、作業の流れを追跡
- 特定の設計ドキュメントが実際に参照されているかを検証

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

| OTEL メトリクス名 | VictoriaMetrics での実際の名前 | 単位 | 属性 |
|------------------|-------------------------------|------|------|
| `claude_code.session.count` | `claude_code_session_count_total` | count | - |
| `claude_code.active_time.total` | `claude_code_active_time_seconds_total` | seconds | - |
| `claude_code.cost.usage` | `claude_code_cost_usage_USD_total` | USD | `model` |
| `claude_code.token.usage` | `claude_code_token_usage_tokens_total` | tokens | `type` (input/output/cacheRead/cacheCreation), `model` |
| `claude_code.lines_of_code.count` | `claude_code_lines_of_code_count_total` | count | `type` (added/removed) |
| `claude_code.commit.count` | `claude_code_commit_count_total` | count | - |
| `claude_code.pull_request.count` | `claude_code_pull_request_count_total` | count | - |
| `claude_code.code_edit_tool.decision` | `claude_code_code_edit_tool_decision_total` | count | `tool`, `decision` (accept/reject), `language` |

> **Note:** OTEL → Prometheus 変換時に単位がメトリクス名に付加される（`tokens`, `USD`, `seconds`）。上記の名前は VictoriaMetrics API (`/api/v1/label/__name__/values`) で実際に確認済み。

### ログイベント一覧（5種類）

Claude Code が OTEL ログプロトコルで送信する全イベント。

| イベント名 | 内容 | 主な属性 |
|-----------|------|---------|
| `claude_code.tool_result` | ツール実行結果 | `tool_name`, `success`, `duration_ms`, `tool_parameters`\*, `decision_source`, `decision_type` |
| `claude_code.user_prompt` | ユーザープロンプト | `prompt_length`, `prompt`\*\* |
| `claude_code.api_request` | API リクエスト | `model`, `cost_usd`, `duration_ms`, `input_tokens`, `output_tokens`, `cache_read_tokens`, `cache_creation_tokens` |
| `claude_code.api_error` | API エラー | `model`, `error`, `status_code`, `duration_ms`, `attempt` |
| `claude_code.tool_decision` | ツール許可判断 | `tool_name`, `decision`, `source` |

### tool_result の tool_name 値とパラメータ（ソースコード確認済み）

`tool_name` はツール種類によってサニタイズされる。特に MCP ツールは実際のツール名ではなく `"mcp_tool"` に統一される。

| ツール種類 | `tool_name` | `tool_parameters` | 備考 |
|-----------|-------------|-------------------|------|
| 組み込みツール (Edit, Read, Write, Glob 等) | そのまま (`"Edit"`, `"Read"` 等) | なし | |
| Bash | `"Bash"` | `{"bash_command":"...", "full_command":"...", "description":"...", "sandbox":"..."}` | 常にあり |
| MCP ツール | **`"mcp_tool"`** | `{"mcp_server_name":"...", "mcp_tool_name":"..."}` | `OTEL_LOG_TOOL_DETAILS=1` 時のみ。追加で `mcp_server_scope` がトップレベル属性として付与 |
| スキル / カスタムコマンド | **`"Skill"`** | `{"skill_name":"doc-check"}` | `OTEL_LOG_TOOL_DETAILS=1` 時のみ |
| エージェント (Task) | **`"Task"`** | なし (null) | subagent_type は取得不可（公式 issue #14784 で NOT_PLANNED） |

\* `tool_parameters` は JSON 文字列。全ツールに存在するわけではなく、上記の Bash / MCP / Skill でのみ出現する。
\*\* `prompt` は `OTEL_LOG_USER_PROMPTS=1` 設定時のみ含まれる（有効化済み）。

### Hooks カスタムイベント（1種類）

ネイティブテレメトリでは取得できないデータを Hooks で補完し、VictoriaLogs に直接送信するカスタムイベント。OTEL Collector は経由しない。

| イベント名 | 内容 | 送信先 | 属性 |
|-----------|------|--------|------|
| `hook.file_read` | Read ツールで読んだファイルパス | VictoriaLogs JSON Lines API (`cc-analyzer:9428/insert/jsonline`) | `file_path`, `file_extension`, `session_id`, `user.name`, `project.name`, `cwd` |

**設定ファイル:** `.claude/settings.json` の `hooks.PreToolUse`（matcher: `"Read"`, async: `true`）
**スクリプト:** `.claude/hooks/log-file-reads.sh`

### 共通属性

全てのメトリクス・イベントに付与されるリソース属性。

| 属性 | 値 |
|------|-----|
| `service.name` | `claude-code` |
| `service.version` | Claude Code バージョン（`OTEL_METRICS_INCLUDE_VERSION=true` で有効化済み） |
| `os.type` | `darwin` / `linux` / `windows` |
| `host.arch` | `amd64` / `arm64` |
| `terminal.type` | `iTerm.app` / `vscode` / `cursor` 等 |
| `user.name` | `OTEL_RESOURCE_ATTRIBUTES` で設定した値 |
| `project.name` | `OTEL_RESOURCE_ATTRIBUTES` で設定した値 |
