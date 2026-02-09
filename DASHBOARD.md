# ダッシュボードで見れる情報一覧

## ダッシュボード構成

2つのダッシュボードで構成される。管理者向けの「組織横断ダッシュボード」と、チームの日常利用向けの「チームダッシュボード」。

> **Note:** 「ユーザー別」のフィルター・グラフは、各メンバーが `setup-member.sh` を実行済みの場合のみ機能する。未実行のメンバーのデータは `user.name` 属性なしで記録され、User フィルターに表示されない。

### 組織横断ダッシュボード（overview.json）

組織全体の利用状況を俯瞰する管理者向けダッシュボード。

**フィルター:** 事業部 (BU) → チーム → Project → User の4階層カスケードフィルター

```
[事業部 (BU): All ▼] [チーム: All ▼] [Project: All ▼] [User: All ▼]
```

| ビュー | 操作 |
|-------|------|
| 全社ビュー | 全部 "All" → 組織全体の集計 |
| 事業部ビュー | BU を選択 → その BU 配下のチーム・プロジェクト・ユーザーに絞り込み |
| チームビュー | チームを選択 → そのチームのメンバーに絞り込み |
| 個人ビュー | ユーザーを選択 → 自分のデータのみ |

### チームダッシュボード（team-template.json）

チーム内の開発活動を詳細に分析するダッシュボード。チームごとにコピーしてカスタマイズ可能。

**フィルター:** Project → User の2階層 + Turn ID（テキスト入力）

```
[Project: All ▼] [User: All ▼] [Turn ID: ___]
```

---

## 組織横断ダッシュボードのパネル

### 1. 概要

セッション数・合計コスト・合計トークン・アクティブ時間・キャッシュ効率・セッション単価の6つの stat パネル。

**わかること:** チーム全体の Claude Code 活用度とコスト効率を一目で把握できる。

**分析例:**
- 週次でコストの推移を追い、予算管理に活用
- アクティブ時間とセッション数の比率で「1セッションあたりの平均作業時間」を推定
- キャッシュ効率が低い場合、CLAUDE.md の整備やプロジェクト構成の見直しを検討
- セッション単価でコスト効率のトレンドを把握

### 2. セッション & アクティビティ

ユーザー別のセッション数とアクティブ時間の時系列バーチャート。

**わかること:** 誰がどれくらい Claude Code を使っているか。活用度の偏りや時間帯の傾向。

**分析例:**
- 特定メンバーの利用が少ない場合、オンボーディング支援やスキル改善の検討材料に
- 曜日・時間帯のパターンから、チームのワークスタイルを把握
- 新規メンバーの立ち上がり（利用開始〜定着）をトラッキング

### 3. トークン & コスト

タイプ別トークン使用量（input/output/cacheRead/cacheCreation）、ユーザー別コスト、モデル別コスト、ユーザー別コストランキング（横棒グラフ）の4パネル。

**わかること:** トークンの消費内訳とコスト構造。どのモデルにいくらかかっているか。ユーザー間のコスト比較。

**分析例:**
- `cacheRead` の割合が高いほどキャッシュが効いており、コスト効率が良い
- `cacheCreation` が急増していたら、コンテキストの大幅な変更が頻発している可能性
- モデル別コストで Opus vs Sonnet のコスト比率を把握し、モデル選択の最適化を検討
- ユーザー別コストランキングでコスト上位のユーザーを特定し、使い方のヒアリングや改善提案の材料に

### 4. コード変更

コード追加/削除行数、コミット & PR 数の2パネル。

**わかること:** Claude Code がどれだけコードを生成・変更しているか。組織全体のアウトプット傾向。

**分析例:**
- 追加行数 vs 削除行数の比率で「新規開発 vs リファクタリング」の傾向を把握
- コミット・PR 数の推移で開発アウトプットへの貢献度を測定

---

## チームダッシュボードのパネル

### 1. 概要

セッション数・合計コスト・合計トークン・アクティブ時間・キャッシュ効率・Edit/Write 承認率・セッション単価の7つの stat パネル（2行構成）。

**わかること:** チームの活用度に加え、キャッシュ効率・承認率・コスト効率を一画面で把握。

**分析例:**
- キャッシュ効率が低い場合、CLAUDE.md やプロジェクト構成の見直しを検討
- 承認率が低い場合、プロンプトの質やスキル設定の改善が必要なサイン
- セッション単価の推移で、コスト最適化の効果を追跡

### 2. トークン & コスト

タイプ別トークン使用量、ユーザー別コスト、モデル別コスト、キャッシュ効率推移の4パネル。

**わかること:** トークンの消費内訳、コスト構造、キャッシュ効率の時系列変化。

**分析例:**
- キャッシュ効率推移で CLAUDE.md 変更やプロジェクト切替の影響を追跡
- 効率が急落したタイミングを特定し、原因を調査（コンテキスト変更、新プロジェクト開始等）

### 3. コード変更

コード追加/削除行数、コミット & PR 数、Edit/Write の承認 vs 却下率、言語別判断の4パネル。

**わかること:** Claude Code がどれだけコードを生成・変更しているか。ユーザーがその提案をどの程度受け入れているか。

**分析例:**
- Reject 率が高い場合、プロンプトの質やスキル設定の改善が必要なサイン
- 言語別の Accept 率で、Claude Code が得意/不得意な言語を特定

### 4. ツール & API（collapsed）

API リクエストログ、API エラーログ、API エラーパターン（テーブル）、ツール失敗ログ、Bash コマンドログ、MCP サーバー呼び出し、スキル & コマンドの7パネル。初期表示では折りたたみ。

**わかること:** API リクエストの詳細（モデル、コスト、レスポンス時間、トークン数、キャッシュ利用状況）、エラーの発生状況とパターン、ツールの失敗状況、Bash 実行内容、MCP/スキルの呼び出し状況。

**分析例:**
- API エラーパターンテーブルで `status_code` 別の発生回数を確認。429（レート制限）が多ければ使用ペースの調整を検討
- `duration_ms` が長いリクエストを特定し、パフォーマンスボトルネックを発見
- ツール失敗ログで頻発するエラーパターンを特定し、権限設定やスキルの改善に活用
- Bash コマンドログで、実行されているコマンドの安全性を監査

### 5. 利用パターン分析

ツール使用分布（横棒グラフ）、ファイル拡張子別分布（横棒グラフ）、スキル利用頻度（テーブル）、MCP ツール利用頻度（テーブル）、スラッシュコマンド利用頻度（テーブル）の5パネル。

**わかること:** Claude Code の使われ方のパターン。どのツールが多用されているか、どんなファイルが読まれているか、カスタム拡張機能の浸透度。

**分析例:**
- ツール使用分布で Read が多い＝調査中心、Edit が多い＝実装中心、などのチームの作業傾向を把握
- ファイル拡張子別分布で `.ts` が多ければ TypeScript プロジェクトが中心、`.md` が多ければドキュメント参照が多い等
- スキル利用頻度テーブルで `/doc-check` や `/tf-check` の利用回数を定量化し、チームへの浸透度を測定
- MCP ツール利用頻度テーブルで、サーバー・ツール別の利用回数を把握し、投資対効果を評価
- 利用されていないカスタムツールがあれば、廃止や改善を検討

### 6. ファイル読み込み追跡（collapsed）

ターン一覧、ターン内アクティビティ、.md ファイル読み込み頻度（テーブル）の3パネル。初期表示では折りたたみ。

#### なぜ Hooks が必要か

Claude Code のネイティブテレメトリでは、Read ツールの `tool_result` イベントに `tool_name: "Read"` は記録されるが、**読み込んだファイルパスは送信されない**（組み込みツールの `tool_parameters` は null）。そのため「どのファイルを読んだか」はテレメトリだけでは追跡できない。

これを補完するために Claude Code の **Hooks 機能**を使い、2つのカスタムイベントを VictoriaLogs に送信する:
1. **`UserPromptSubmit` hook（同期）** — ユーザーがプロンプトを送信した瞬間に `turn_id` を生成し、temp ファイルに保存 + VictoriaLogs に送信
2. **`PreToolUse` Read hook（async）** — Read ツール呼び出し時に `file_path` と `turn_id` を VictoriaLogs に送信

#### 仕組み（ターン単位の追跡）

```
ユーザーがプロンプトを送信
  │
  ▼ UserPromptSubmit hook（同期）
  │   → .claude/hooks/track-turn.sh
  │     1. turn_id を生成（session_id先頭8文字 + Unixタイムスタンプ）
  │     2. /tmp/claude-turn/{session_id}.turn_id に書き込み
  │     3. hook.user_turn イベントを VictoriaLogs に送信
  │
  ▼ Claude が処理を開始、Read ツールを呼び出す
  │
  ▼ PreToolUse Read hook（async）× 読んだファイル数だけ発火
  │   → .claude/hooks/log-file-reads.sh
  │     1. temp ファイルから turn_id を読み込み
  │     2. file_path + file_name + turn_id を hook.file_read イベントとして VictoriaLogs に送信
  │
  ▼ Grafana
  └── turn_id でフィルターし「このプロンプトで何が読まれたか」を表示
```

**なぜ temp ファイルを使うか:** Claude Code の hooks は環境変数をフック間で共有できない（GitHub issue #9567 で NOT_PLANNED）。ファイルシステム経由の IPC が唯一の方法。

**OTEL Collector を経由しない理由:** OTLP/gRPC で curl から送信するには protobuf JSON 形式が必要で複雑。VictoriaLogs の JSON Lines API（`/insert/jsonline`）は HTTP POST で1行 JSON を送るだけのシンプルな API。

#### ダッシュボードでの使い方

1. **ターン一覧パネル**でプロンプトと `turn_id` を確認
2. `turn_id` をコピーし、ダッシュボード上部の **Turn ID** 変数に貼り付け
3. **ターン内アクティビティパネル**が自動で絞り込まれ、そのプロンプトで読まれた全ファイルが表示される

#### .md ファイル読み込み頻度テーブル

`.md` 拡張子のファイルをパス別に集計し、読み込み回数でソートしたテーブル。

**わかること:** どのマークダウンファイルがどれだけ参照されているか。CLAUDE.md やカスタムコマンド定義がどれだけ活用されているか。

**ドキュメント最適化への活用:** よく読まれている .md は重要なドキュメント。読まれていない長い説明は省き、よく読まれるが不足している説明は足す。不要な文章を削り必要な文章を付け足す PDCA をデータで回せる。

#### パフォーマンスへの影響

- **UserPromptSubmit hook（同期）:** jq + ファイル書き込み + curl で約 100ms。プロンプト送信時の体感遅延は無視できるレベル
- **PreToolUse Read hook（async）:** バックグラウンド実行のため影響なし
- **VM のリソース:** 影響なし。hook イベントは 1件あたり約 200 バイト。5人 × 50 Read/セッション × 3セッション/日 = 約 750 リクエスト/日
- **ネットワーク障害時:** curl に `--max-time 2` のタイムアウトと `|| true` を設定済み

#### 前提条件

- `jq` が必要（`brew install jq`）。hook スクリプト内で JSON パースに使用
- Tailscale 接続中であること（`cc-analyzer:9428` に到達可能な状態）

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

### Hooks カスタムイベント（3種類）

ネイティブテレメトリでは取得できないデータを Hooks で補完し、VictoriaLogs に直接送信するカスタムイベント。OTEL Collector は経由しない。

| イベント名 | 内容 | Hook | 属性 |
|-----------|------|------|------|
| `hook.user_turn` | ユーザーのプロンプト送信（ターン開始） | `UserPromptSubmit`（同期） | `turn_id`, `session_id`, `prompt`（全文）, `user.name`, `project.name`, `bu.name`, `team.name` |
| `hook.file_read` | Read ツールで読んだファイルパス | `PreToolUse` Read（async） | `file_path`, `file_extension`, `file_name`, `turn_id`, `session_id`, `user.name`, `project.name`, `bu.name`, `team.name`, `cwd` |
| `hook.mcp_use` | MCP ツール呼び出し | `PreToolUse` mcp\_\_.\*（async） | `tool_name`（フル名）, `mcp_server`, `mcp_tool`, `session_id`, `user.name`, `project.name`, `bu.name`, `team.name` |

**送信先:** VictoriaLogs JSON Lines API (`cc-analyzer:9428/insert/jsonline`)

**スクリプト:**
- `.claude/hooks/track-turn.sh` — turn_id 生成 + temp ファイル書き込み + user_turn イベント送信
- `.claude/hooks/log-file-reads.sh` — temp ファイルから turn_id 読み込み + file_read イベント送信
- `.claude/hooks/log-mcp-usage.sh` — MCP ツール名をパースして mcp_use イベント送信

**turn_id の仕組み:** `UserPromptSubmit` hook が `/tmp/claude-turn/{session_id}.turn_id` に turn_id を書き込み、`PreToolUse` Read hook がそこから読み込む。hooks 間の環境変数共有は不可のため（GitHub issue #9567）、ファイルシステム経由の IPC を使用。

### 共通属性

全てのメトリクス・イベントに付与されるリソース属性。

| 属性 | 値 |
|------|-----|
| `service.name` | `claude-code` |
| `service.version` | Claude Code バージョン（`OTEL_METRICS_INCLUDE_VERSION=true` で有効化済み） |
| `os.type` | `darwin` / `linux` / `windows` |
| `host.arch` | `amd64` / `arm64` |
| `terminal.type` | `iTerm.app` / `vscode` / `cursor` 等 |
| `bu.name` | 事業部名（`OTEL_RESOURCE_ATTRIBUTES` で設定） |
| `team.name` | チーム名（`OTEL_RESOURCE_ATTRIBUTES` で設定） |
| `user.name` | ユーザー名（`OTEL_RESOURCE_ATTRIBUTES` で設定） |
| `project.name` | プロジェクト名（`OTEL_RESOURCE_ATTRIBUTES` で設定） |
