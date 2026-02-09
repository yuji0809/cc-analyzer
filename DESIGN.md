# Claude Code Team Dashboard 設計書

## 1. プロジェクト概要

### 1.1 背景と動機

チーム（開発者5名程度）でClaude Codeを導入しているが、メンバーごとに活用度にばらつきがある。誰がどれくらい使っているか、どのツール・スキル・MCP サーバーが活用されているかが見えない状態では、チーム全体の活用水準を引き上げることが難しい。

本プロジェクトでは、Claude Codeのテレメトリと `/insights` コマンドのデータを収集・可視化するダッシュボードを構築し、チームの活用状況を「見える化」する。

### 1.2 このシステムで実現できること

- **メンバーごとの利用状況の可視化**: 誰がどれくらいClaude Codeを使っているか（セッション数、トークン消費量）
- **ツール利用の把握**: Edit, Bash, Read, TodoWrite, TaskCreate 等の各ツールがどの程度使われているか
- **スキル・MCP活用の追跡**: どのスキルファイル（.md）が読まれているか、どのMCPサーバーが呼ばれているかを時系列で追跡
- **改善施策の効果測定**: 「スキルAが全然読まれていない」→ 改善 → 「利用が増えた」を数値で確認
- **ドキュメント（.md）の最適化**: どの .md がいつ読まれているかを追跡し、読まれない冗長な記述は省く・不足している説明は足す、といった PDCA に活用
- **セッション品質の傾向分析**: 成功率、満足度、フリクション（摩擦）の推移
- **チーム比較**: メンバー間の利用パターンの違いを発見し、ベストプラクティスを共有

### 1.3 期待される効果

- チーム全体のClaude Code活用水準の底上げ
- 「誰も使っていないスキルやMCPサーバー」の発見と啓蒙
- 改善施策（スキルファイルの改善、MCPの追加等）のPDCA高速化
- ドキュメントの最適化（どの .md がいつ読まれるかのデータで、不要な文章を省き必要な文章を足す判断ができる）
- メンバー同士のナレッジ共有促進（「○○さんはこのMCPをよく使ってて生産性高い」等）

---

## 2. システム全体像

### 2.1 アーキテクチャ図

```
┌─────────────────────────────────────────────────────────────────┐
│                     各メンバーのローカルPC                         │
│                                                                 │
│  ┌──────────────┐    環境変数でOTEL送信を有効化                    │
│  │  Claude Code  │──────────────────────────────────┐            │
│  └──────────────┘                                    │            │
│         │                                            │            │
│    テレメトリデータ（自動送信）                  /insights コマンド │
│    - ツール使用回数                           （手動 or スクリプト）│
│    - セッション情報                                  │            │
│    - MCP呼び出し                                     │            │
│    - スキルファイル読み込み                            │            │
└─────│────────────────────────────────────────────────│────────────┘
      │ gRPC (OTLP)                                   │ HTTP POST
      │ via Tailscale VPN (100.x.x.x)                 │
      ▼                                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                 GCE e2-micro (us-central1)                       │
│                 GCP Always Free 枠 + Tailscale VPN               │
│                                                                 │
│  ┌──────────────────┐     ┌────────────────────┐                │
│  │  OTEL Collector   │     │  VictoriaMetrics    │                │
│  │  :4317 (gRPC)     │────▶│  :8428              │                │
│  │                   │     │                    │                │
│  │  テレメトリ受信    │     │  メトリクス保存     │                │
│  │  データ変換・集約   │     │  (1年保持)          │                │
│  └──────────────────┘     └────────┬───────────┘                │
│           │                        │                            │
│           │ ログ転送                │ クエリ (MetricsQL)          │
│           ▼                        ▼                            │
│  ┌──────────────────┐     ┌────────────────────┐                │
│  │  VictoriaLogs     │     │  Grafana            │                │
│  │  :9428             │────▶│  :3000              │                │
│  │                   │     │                    │                │
│  │  ログ保存          │     │  ダッシュボード     │                │
│  │  (90日保持)        │     │  可視化・アラート    │                │
│  └──────────────────┘     └────────────────────┘                │
│                                    ▲                            │
│                                    │ ブラウザアクセス             │
│                                    │ (Tailscale VPN経由のみ)     │
└────────────────────────────────────│────────────────────────────┘
                                     │ Tailscale VPN
                              メンバーがブラウザで閲覧
                              (Tailscale接続必須)
```

### 2.2 データの流れ（詳細）

#### リアルタイムテレメトリの流れ

```
1. メンバーがClaude Codeでコーディング作業を行う
   │
2. Claude Codeが自動的にテレメトリデータを生成
   │ （環境変数 CLAUDE_CODE_ENABLE_TELEMETRY=1 により有効化）
   │
3. OTLP (gRPC) プロトコルでOTEL Collectorに送信
   │ （OTEL_EXPORTER_OTLP_ENDPOINT で送信先を指定）
   │
4. OTEL Collectorがデータを受信
   │
   ├─── メトリクスデータ ──▶ VictoriaMetrics に保存
   │    （ツール使用回数、セッション数、トークン消費量等）
   │
   └─── ログデータ ──────▶ VictoriaLogs に保存
        （ツール実行の詳細ログ、エラー情報等）
   │
5. Grafanaが VictoriaMetrics / VictoriaLogs にクエリ
   │
6. ダッシュボード上でグラフ・テーブルとして可視化
```

#### Hooks による補完データの流れ

既存のテレメトリだけでは取得できない情報（例: Read ツールでどのファイルが読まれたか）がある。そのため Hooks（PreToolUse 等）で補足イベントを発生させ、VictoriaLogs の JSON Lines API に HTTP POST で送信し、Grafana の同じダッシュボードから参照できるようにしている。OTEL Collector は経由せず、各メンバーの環境から Tailscale 経由で `cc-analyzer:9428` に直接送る。

```
Claude Code (Read 実行時など)
  │ PreToolUse hook 発火 (async) → .claude/hooks/log-file-reads.sh 等
  │ スクリプトが file_path, user.name, project.name 等を JSON 化
  ▼
VictoriaLogs :9428/insert/jsonline (HTTP POST)
  │
  ▼
Grafana でクエリ・可視化（テレメトリログと同一ダッシュボード）
```

#### /insights データの流れ（将来フェーズ）

```
1. メンバーがClaude Codeで /insights コマンドを実行
   │
2. 直近1ヶ月のセッションサマリーがHTMLで表示される
   │
3. 収集スクリプトがHTMLからJSONを抽出
   │
4. JSONデータをVictoriaMetricsにpush（HTTPネイティブ対応）
   │
5. Grafanaのダッシュボードに反映
```

---

## 3. 各コンポーネントの役割

### 3.1 OTEL Collector（OpenTelemetry Collector）

**役割**: テレメトリデータの受信ゲートウェイ

| 項目 | 内容 |
|------|------|
| ポート | :4317 (gRPC) |
| 入力 | Claude Codeからの OTLP データ |
| 出力 | メトリクス → VictoriaMetrics, ログ → VictoriaLogs |
| メモリ目安 | ~100MB |

Claude Codeは OpenTelemetry に準拠したテレメトリを出力する。OTEL Collectorはその受け口となり、受信したデータを適切なバックエンド（VictoriaMetrics / VictoriaLogs）に振り分ける。

**具体的に受信するデータ:**

- セッションの開始・終了
- ツール呼び出し（Edit, Read, Bash, Write, TodoWrite, TaskCreate等）
- MCP サーバーの呼び出し（`OTEL_LOG_TOOL_DETAILS=1`設定時、サーバー名も取得可能）
- スキルファイルの読み込み（`OTEL_LOG_TOOL_DETAILS=1`設定時、ファイル名も取得可能）
- トークン消費量
- エラー・例外

### 3.2 VictoriaMetrics

**役割**: 時系列メトリクスDB（Prometheusの代替）

| 項目 | 内容 |
|------|------|
| ポート | :8428 |
| 保持期間 | 1年（365日） |
| クエリ言語 | MetricsQL（PromQL上位互換） |
| メモリ目安 | ~100-150MB |

Prometheusと互換性を持ちながら、メモリ消費量が約4分の1、CPU消費量が約7分の1という軽量な時系列DB。e2-micro（1GB RAM）で安定動作するために選定。

**Prometheusではなく VictoriaMetrics を選定した理由:**

- メモリ使用量が安定しており、スパイクによるOOM（メモリ不足クラッシュ）のリスクが低い
- Push モデルをネイティブサポート（Pushgateway不要で /insights データを直接投入可能）
- シングルバイナリでデプロイがシンプル
- 長期保存に最適化された圧縮・ストレージ設計

**保存するメトリクスの例:**

```
# メンバー別セッション数
claude_code_sessions_total{user="yuji"} 42

# ツール別使用回数
claude_code_tool_calls_total{user="yuji", tool="Edit"} 156
claude_code_tool_calls_total{user="yuji", tool="Bash"} 89

# スキルファイル読み込み回数
claude_code_skill_read_total{user="yuji", skill="pptx/SKILL.md"} 12

# MCP サーバー呼び出し回数
claude_code_mcp_call_total{user="tanaka", server="github"} 30

# トークン消費量
claude_code_tokens_total{user="yuji", type="input"} 50000
```

これらは全て数値データなので、1年分保存しても数百MB程度。30GBディスクの無料枠で余裕。

### 3.3 VictoriaLogs

**役割**: ログ保存・全文検索DB（Grafana Lokiの代替）

| 項目 | 内容 |
|------|------|
| ポート | :9428 |
| 保持期間 | 90日 |
| クエリ言語 | LogsQL |
| メモリ目安 | ~100-150MB |

Grafana Lokiと同じログ集約の役割だが、メモリ使用量87%減、CPU使用量72%減（ベンチマーク比較）。シングルバイナリでゼロコンフィグ。

**Lokiではなく VictoriaLogs を選定した理由:**

- Lokiは最低6-7GB RAMが必要で、e2-micro（1GB）では動作不可能
- VictoriaLogsはRaspberry Piでも動作する軽量設計
- VictoriaMetricsと同じチームが開発しており、設定・運用の一貫性が高い

**保存するログの例:**

- ツール実行の詳細（どのファイルをEditしたか、どのコマンドをBashで実行したか）
- MCP サーバーの呼び出し詳細
- エラー・例外の詳細メッセージ

**メトリクスとの使い分け:**

| 知りたいこと | 参照先 |
|---|---|
| 「先月Editツールが何回使われたか」 | VictoriaMetrics（メトリクス） |
| 「あのセッションでBashが失敗した原因は何か」 | VictoriaLogs（ログ） |
| 「スキルAの利用が6ヶ月で増えたか」 | VictoriaMetrics（メトリクス、1年保持） |
| 「昨日のMCP呼び出しのリクエスト内容」 | VictoriaLogs（ログ、90日保持） |

メトリクスは「傾向」を見るためのもので長期保持。ログは「詳細調査」のためのもので90日あれば十分。

### 3.4 Grafana

**役割**: 統合ダッシュボード・可視化

| 項目 | 内容 |
|------|------|
| ポート | :3000 |
| データソース | VictoriaMetrics, VictoriaLogs |
| 認証 | ログイン（初回パスワード変更） |
| メモリ目安 | ~150-200MB |

収集した全データを一箇所で可視化するUI。GUIでパネル（グラフ、テーブル、ゲージ等 約20種類）をドラッグ＆ドロップで配置してダッシュボードを構成する。

**ダッシュボードのカスタマイズ性:**

- パネルの種類: 折れ線グラフ、棒グラフ、ゲージ、テーブル、ヒートマップ、円グラフ等
- フィルター: メンバー別、期間別、ツール別の動的切り替え（プルダウン）
- アラート: 条件に応じた通知（例: セッション成功率が50%以下でSlack通知）
- ダッシュボードはJSON形式で内部管理されており、エクスポート→Gitに保存→自動復元が可能

**デザインの制約:**

Grafanaは用意されたパネルタイプの組み合わせ（グリッドベースレイアウト）なので、完全に自由なWebデザインはできない。ただし、VictoriaMetricsへのAPIアクセスが可能なので、将来的に独自のNext.js/AstroフロントエンドでカスタムUIを構築する拡張パスもある。

**想定ダッシュボード構成:**

```
┌──────────────────────────┬──────────────────────────┐
│ 今週のセッション数         │ メンバー別ツール使用率      │
│ (棒グラフ・メンバー別)      │ (積み上げグラフ)           │
├──────────────────────────┼──────────────────────────┤
│ セッション成功率の推移      │ よく使われるMCPサーバー     │
│ (折れ線・メンバー別)        │ (テーブル)                │
├──────────────────────────┴──────────────────────────┤
│ スキル利用トレンド（過去6ヶ月）                         │
│                                                      │
│ pptx/SKILL.md  ▁▁▂▃▅▇  ← 改善後に利用急増            │
│ docx/SKILL.md  ▇▇▆▅▅▅                               │
│ xlsx/SKILL.md  ▁▁▁▁▁▁  ← 誰も使っていない → 要改善    │
├──────────────────────────┬──────────────────────────┤
│ MCP利用トレンド            │ トークン消費量推移          │
│ github  ▃▅▆▇▇▇           │ (折れ線・メンバー別)        │
│ slack   ▁▁▁▂▃▅           │                           │
└──────────────────────────┴──────────────────────────┘
```

---

## 4. 収集できるデータの詳細

### 4.1 OpenTelemetry テレメトリ（自動収集）

Claude Codeが `CLAUDE_CODE_ENABLE_TELEMETRY=1` 設定時に自動送信するデータ。

| カテゴリ | データ項目 | 活用方法 |
|---------|-----------|---------|
| セッション | 開始時刻、終了時刻、持続時間 | 利用頻度・利用時間帯の分析 |
| ツール使用 | Edit, Read, Bash, Write, TodoWrite, TaskCreate 等の呼び出し回数 | ツール活用パターンの比較 |
| MCP | サーバー名、呼び出し回数（`OTEL_LOG_TOOL_DETAILS=1`時） | MCP活用度の追跡 |
| スキル | 読み込まれたスキルファイル名（`OTEL_LOG_TOOL_DETAILS=1`時） | スキル認知度・活用度の測定 |
| トークン | 入力・出力トークン数 | コスト分析、効率性の指標 |
| タスク | TaskCreate（サブタスク）の使用有無 | 高度な機能の活用度 |
| エラー | 例外・失敗の発生 | トラブルの傾向分析 |

### 4.2 /insights コマンドデータ（手動 or スクリプト収集）

Claude Codeの `/insights` コマンドが出力する直近1ヶ月のサマリーデータ。OpenTelemetryでは取れない定性的な情報が含まれる。

| カテゴリ | データ項目 | 活用方法 |
|---------|-----------|---------|
| セッション目標 | 13カテゴリ（debug_investigate, implement_feature等） | どんな作業にClaude Codeを使っているか |
| 成果 | 5段階（not_achieved → fully_achieved） | セッション品質の傾向 |
| 満足度 | 6段階（frustrated → happy） | ユーザー体験の追跡 |
| フリクション | 12カテゴリ（misunderstood_request, buggy_code等） | 改善すべきポイントの発見 |
| プログラミング言語 | ファイル拡張子から推定 | プロジェクト別の活用状況 |
| Git活動 | コミット数、プッシュ数 | Claude Codeの成果物が実際にマージされているか |
| コード変更 | 追加行数、削除行数、変更ファイル数 | 生産性の指標 |

### 4.3 取得できないデータ

以下のデータは現状の仕組みでは取得できない。

| データ | 理由 |
|-------|------|
| プロンプトの具体的な内容 | /insightsでは先頭プロンプトとサマリーのみ |
| カスタムスラッシュコマンドの使用状況 | テレメトリに含まれない |
| Hooksの発火状況 | テレメトリに含まれない |
| MCP サーバーのリクエスト/レスポンス内容 | フラグのみ（詳細は含まれない） |

---

## 5. インフラ構成

### 5.1 GCE インスタンス

| 項目 | 設定値 | 理由 |
|------|--------|------|
| マシンタイプ | e2-micro | Always Free 枠対象 |
| リージョン | us-central1 | Always Free 枠対象（us-west1, us-east1も可） |
| OS | Ubuntu 24.04 LTS | Docker公式サポート |
| ディスク | 30GB Standard Persistent Disk | Always Free 上限 |
| 外部IP | 静的IPアドレス | インスタンス稼働中は無料 |

**注意: Always Free 枠の条件**

- e2-micro のみ（e2-small はNG → 月~$5 発生）
- us-central1, us-west1, us-east1 のみ（asia-northeast1等はNG → 月~$7 発生）
- Standard Persistent Disk のみ（Balanced/SSD はNG）
- ネットワーク下り: 1GB/月（北米宛）

### 5.2 GCE を選定した理由

Cloud Run や GKE ではなく GCE を採用した理由は以下の通り。

| 観点 | GCE (採用) | Cloud Run (不採用) |
|------|-----------|-------------------|
| ステート | VictoriaMetrics/Logs がディスクにデータを永続化。ボリュームマウントが必須 | ステートレス前提。コンテナ再起動でデータ消失 |
| 常時起動 | OTEL Collector が gRPC (4317) でテレメトリを常時受け付ける必要がある | リクエストがないとスケールゼロ。常時待ち受けに不向き |
| 複数コンテナ | Docker Compose で 4 サービスが localhost で通信 | サービスごとに別デプロイ。ネットワーク設定が複雑化 |
| Tailscale | デーモンが常駐して VPN トンネルを維持 | エフェメラルなコンテナでは VPN 維持が不可能 |
| コスト | e2-micro は Always Free 枠で $0/月 | 4 サービスを 24/7 稼働させると課金発生 |

要約すると、**常時起動 + ステートフル + 複数コンテナ連携 + VPN = GCE が最適**という判断。

### 5.3 メモリ配分

e2-micro の 1GB RAM で 4 コンテナを動かすためのメモリ計画。

| コンポーネント | メモリ上限設定 | 備考 |
|-------------|-------------|------|
| OTEL Collector | 128MB | 軽量、受信のみ |
| VictoriaMetrics | 192MB | メモリ消費が安定（スパイクなし） |
| VictoriaLogs | 192MB | シングルバイナリ、ゼロコンフィグ |
| Grafana | 256MB | ダッシュボード描画 |
| OS + Docker | ~200MB | - |
| swap | 1-2GB | ピーク時のバッファ |
| **合計** | **~650-850MB** | 1GB以内に収まる |

startup.sh で 1-2GB の swapfile を作成し、ピーク時のOOMを防止する。

### 5.4 セキュリティ

Tailscale VPN によるゼロトラストネットワークを採用。インターネットへのポート公開を排除し、HTTPS + Google OAuth SSO で多層防御を実現。

| 対策 | 内容 |
|------|------|
| ネットワーク | Tailscale VPN 経由のみ。OTEL(:4317) はインターネットに非公開 |
| HTTPS | Tailscale HTTPS (`tailscale serve`) により Let's Encrypt 証明書を自動取得・更新 |
| Grafana認証 | Google OAuth SSO（特定ドメイン制限）+ 管理者パスワード（フォールバック） |
| シークレット管理 | GCP Secret Manager で暗号化保存。VM は実行時にメタデータサーバー経由で取得 |
| SSH | Tailscale 経由の SSH でアクセス（GCPファイアウォールによるポート公開は不要） |
| 暗号化 | Tailscale は WireGuard ベース。全通信がエンドツーエンドで暗号化。Grafana は追加で TLS |
| アクセス制御 | Tailnet に参加したデバイスのみアクセス可能。Tailscale Admin Console でデバイス管理 |

**Tailscale の役割 — ファイアウォール + VPN + DNS + HTTPS を兼務:**

通常、GCE でサービスを公開する場合はファイアウォールルール（ポート開放、IP制限）、HTTPS化（証明書管理）、アプリケーション層の認証強化が必要になる。本構成では Tailscale がこれらを全て代替している。

```
通常の構成:
  ブラウザ → インターネット → GCE公開IP:3000 → Grafana
                                ↑
                     ファイアウォールで制御が必要
                     (IP制限、認証、HTTPS化...)

本構成 (Tailscale HTTPS経由):
  ブラウザ → Tailscale暗号化トンネル → tailscale serve (TLS終端, :443)
             (同じTailnetのメンバーだけ)        ↓
                                         → localhost:3000 → Grafana
                                           (127.0.0.1のみ、外部アクセス不可)
```

これにより GCE ファイアウォールルールは一切不要で、パブリック IP にはどのポートも公開していない。Grafana へのアクセスは `https://cc-analyzer.<tailnet>.ts.net` の HTTPS のみ。

**Tailscale HTTPS (`tailscale serve`) の仕組み:**

- `tailscale serve --https=443 http://localhost:3000` でリバースプロキシを構成
- Let's Encrypt 証明書を自動取得・更新（手動管理不要）
- Tailnet 内のデバイスからのみアクセス可能（インターネットには非公開）
- Grafana のポートは `127.0.0.1:3000` にバインドし、`tailscale serve` 経由でのみアクセス可能

**Google OAuth SSO:**

- Google Workspace の特定ドメインのアカウントのみログイン可能（`GF_AUTH_GOOGLE_ALLOWED_DOMAINS`）
- 管理者アカウントはパスワード認証でフォールバック可能
- OAuth リダイレクト先: `https://cc-analyzer.<tailnet>.ts.net/login/google`

**Secret Manager によるシークレット管理:**

機密情報（Grafana 管理者パスワード、Tailscale Auth Key、Google OAuth Client Secret）は GCP Secret Manager に保存される。GCE インスタンスの metadata（startup script）には機密値が含まれず、VM は起動時に専用サービスアカウント経由で Secret Manager API から取得する。

```
terraform.tfvars → Terraform → Secret Manager (暗号化 + IAM 制御)
                                      ↓ VM 起動時に取得
                                 startup.sh → docker-compose.yml
```

- Terraform が Secret Manager にシークレットを作成
- GCE VM の専用サービスアカウントに `secretmanager.secretAccessor` ロールを付与
- startup.sh は GCE メタデータサーバーからアクセストークンを取得し、Secret Manager REST API でシークレットを読み取る（gcloud CLI 不要）
- Secret Manager の無料枠（6 シークレット、10,000 アクセス/月）で $0

**Tailscale を採用した理由:**

- ポート公開が不要になり、OTEL/Grafana への不正アクセスリスクがゼロ
- WireGuard ベースで HTTP 通信も VPN トンネル内で暗号化される
- HTTPS 証明書の自動管理（`tailscale serve`）で運用負荷ゼロ
- MagicDNS により `cc-analyzer.<tailnet>.ts.net` のホスト名でアクセス可能
- 無料枠100台で小規模チームには十分
- インストールが簡単（各メンバーは `tailscale up` するだけ）
- GCE インスタンス側も startup script で自動セットアップ

### 5.5 ディスク管理

| データ | 保持期間 | 推定サイズ（5人・保持期間分） |
|-------|---------|------------------------|
| Docker images | - | 3-5GB |
| VictoriaMetrics（メトリクス） | 365日 | 数百MB |
| VictoriaLogs（ログ） | 90日 | 1-3GB |
| Grafana設定 | - | 数十MB |
| **合計** | - | **~5-10GB** |

30GB ディスクに対して十分な余裕がある。retentionの設定により、データは自動的に古いものから削除される。

---

## 6. メンバーセットアップ

### 6.1 プロジェクト単位のテレメトリ設定

テレメトリはシェルのグローバル環境変数（`.zshrc` 等）ではなく、**対象リポジトリの `.claude/settings.json`** で設定する。これにより、テレメトリは設定を置いたリポジトリでのセッションだけに限定され、個人プロジェクトのデータは送信されない。

#### 共有設定（`.claude/settings.json`、Git にコミット）

対象リポジトリのルートに `.claude/settings.json` を作成し、コミットする:

```json
{
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "otlp",
    "OTEL_LOGS_EXPORTER": "otlp",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "grpc",
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://cc-analyzer:4317",
    "OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE": "cumulative",
    "OTEL_LOG_TOOL_DETAILS": "1",
    "OTEL_LOG_USER_PROMPTS": "1",
    "OTEL_METRICS_INCLUDE_VERSION": "true",
    "OTEL_RESOURCE_ATTRIBUTES": "bu.name=BU_NAME,team.name=TEAM_NAME,project.name=REPO_NAME"
  }
}
```

#### 個人設定（`.claude/settings.local.json`、`.gitignore` に追加）

各メンバーは `.claude/settings.local.json` を作成し、`user.name` を追加する。
`user.name` には **Grafana にログインするメールアドレス**を指定する。ダッシュボードの「自分のビュー」リンクが Grafana のログインユーザー（`${__user.login}`）でフィルターするため、一致している必要がある:

```json
{
  "env": {
    "OTEL_RESOURCE_ATTRIBUTES": "user.name=taro@example.com,project.name=REPO_NAME"
  }
}
```

> **Note:** `settings.local.json` は `settings.json` より優先されるため、`OTEL_RESOURCE_ATTRIBUTES` はここで指定した値で上書きされる。`project.name` も忘れずに含めること。

対象リポジトリの `.gitignore` に以下を追加:

```
.claude/settings.local.json
```

### 6.2 セットアップスクリプト

対象リポジトリのルートで以下を実行すると、`.claude/settings.local.json` が自動作成される。

```bash
# 対象リポジトリのルートで実行
/path/to/cc-analyzer/setup-member.sh
```

---

## 7. 使い方・運用ガイド

### 7.1 日常の使い方

メンバーは特に意識することなく、通常通りClaude Codeを使うだけでよい。テレメトリは環境変数設定後、自動的にバックグラウンドで送信される。

**ダッシュボードの確認:**

1. ブラウザで `https://cc-analyzer.<tailnet>.ts.net` を開く（Tailscale接続必須）
2. Google OAuth でログイン（または管理者パスワードでログイン）
3. 「Claude Code Team Dashboard」を開く
4. 期間・メンバーをフィルターで切り替えて閲覧

### 7.2 週次レビュー（推奨）

毎週月曜日に10分程度、ダッシュボードを確認する。

**確認ポイント:**

- 先週のセッション数: チーム全体・メンバー別
- ツール使用の偏り: 特定のツールしか使っていないメンバーがいないか
- スキル・MCP利用: 新しく追加したスキルやMCPが使われ始めているか
- エラー傾向: 特定のツールやMCPでエラーが多発していないか

### 7.3 月次レビュー（推奨）

月に1回、/insightsデータも含めたより深い分析を行う。

**確認ポイント:**

- セッション目標の分布: チームがClaude Codeを何に使っているか
- 満足度・成果の推移: 前月と比べて改善しているか
- フリクション分析: どんな問題が多いか → スキル改善や設定変更の材料に

### 7.4 改善サイクルの例

```
1. ダッシュボードで「xlsx/SKILL.mdが誰にも読まれていない」と発見

2. 原因分析: スキルの存在が知られていない？ 内容が不十分？

3. 施策: Slackでスキルの紹介 + SKILL.mdの内容を改善

4. 翌月のダッシュボードで効果測定:
   xlsx/SKILL.md の read_total が 0 → 15 に増加

5. さらに: そのスキルを使ったセッションの成功率が向上しているか確認
```

---

## 8. IaC（Infrastructure as Code）

### 8.1 Terraform によるインフラ管理

全てのGCPリソースをTerraformで管理する。

```
infra/
  ├── main.tf                    # provider設定
  ├── apis.tf                    # GCP API有効化（compute, iam, secretmanager）
  ├── variables.tf               # 変数定義（リージョン、プロジェクトID等）
  ├── gce.tf                     # GCE インスタンス定義
  ├── secrets.tf                 # Secret Manager、サービスアカウント、IAM
  ├── outputs.tf                 # 出力値（静的IP、接続コマンド等）
  ├── terraform.tfvars           # 変数値（.gitignoreに追加）
  ├── terraform.tfvars.example   # 変数値のテンプレート
  ├── startup.sh                 # インスタンス起動時の自動セットアップ
  ├── docker-compose.yml         # 全コンテナ定義
  ├── otel-collector-config.yaml # OTEL Collector設定
  └── grafana/
      └── provisioning/
          ├── datasources/
          │   └── datasources.yml    # VictoriaMetrics/Logsを自動登録
          └── dashboards/
              ├── dashboards.yml      # ダッシュボードプロビジョニング設定
              ├── overview.json       # 組織横断ダッシュボード（管理者向け）
              └── team-template.json  # チームダッシュボード（テンプレート）
```

> **Note:** Tailscale VPN の採用により `firewall.tf` は不要（5.4 節参照）。

### 8.2 Grafana ダッシュボードのバックアップ

Grafanaのダッシュボードは内部的にJSONで構成されている。GUIで作成したダッシュボードをJSONエクスポートし、Gitリポジトリに保存する。

`terraform destroy` → `terraform apply` でGCEを再構築した場合でも、Grafanaが起動時にprovisioning ディレクトリのJSONを自動読み込みするため、ダッシュボードが自動復元される。

---

## 9. リポジトリ構成

```
cc-analyzer/
  ├── README.md                        # セットアップ手順
  ├── DESIGN.md                        # 本設計書
  ├── DASHBOARD.md                     # ダッシュボードで見れる情報一覧
  ├── setup-member.sh                  # メンバーセットアップスクリプト
  ├── .gitignore
  ├── infra/                           # インフラ関連（Terraform + Docker）
  │   ├── main.tf                      # provider設定
  │   ├── apis.tf                      # GCP API有効化
  │   ├── variables.tf                 # 変数定義
  │   ├── gce.tf                       # GCE インスタンス定義
  │   ├── secrets.tf                   # Secret Manager、サービスアカウント、IAM
  │   ├── outputs.tf                   # 出力値（静的IP、接続コマンド等）
  │   ├── terraform.tfvars             # 変数値（.gitignore）
  │   ├── terraform.tfvars.example     # 変数値のテンプレート
  │   ├── startup.sh                   # インスタンス起動時の自動セットアップ
  │   ├── docker-compose.yml           # 全コンテナ定義
  │   ├── otel-collector-config.yaml   # OTEL Collector設定
  │   └── grafana/
  │       └── provisioning/
  │           ├── datasources/
  │           │   └── datasources.yml
  │           └── dashboards/
  │               ├── dashboards.yml
  │               ├── overview.json       ← 組織横断ダッシュボード
  │               └── team-template.json  ← チームダッシュボード
  └── .claude/
      ├── settings.json                # Claude Code テレメトリ設定（共有）
      ├── settings.local.json          # 個人設定（.gitignore）
      ├── agents/
      │   └── documentation-agent.md   # ドキュメント整合性チェック用エージェント
      ├── hooks/
      │   ├── log-file-reads.sh        # PreToolUse Read hook（ファイル読み込み追跡）
      │   ├── log-mcp-usage.sh         # PreToolUse MCP hook（MCPツール呼び出し追跡）
      │   └── track-turn.sh            # UserPromptSubmit hook（ターンID生成）
      ├── commands/
      │   ├── doc-check.md             # /doc-check コマンド定義
      │   └── tf-check.md              # /tf-check コマンド定義
      └── skills/
          ├── documentation-check.md   # ドキュメントチェックスキル
          ├── terraform-skill.md       # Terraform 操作スキル
          └── terraform-style-guide.md # Terraform スタイルガイド
```

---

## 10. 実装ロードマップ

### Phase 1: インフラ構築（Day 1-2）

- Terraform設定ファイルの作成
- startup.sh の作成（Docker + 全コンテナの自動デプロイ）
- `terraform apply` で GCE インスタンス起動
- swap 設定の確認

### Phase 2: サービス設定・動作確認（Day 3）

- docker-compose.yml の作成（OTEL Collector + VictoriaMetrics + VictoriaLogs + Grafana）
- OTEL Collector の設定（gRPC受信 → VictoriaMetrics/Logs転送）
- Grafana のデータソース自動登録設定
- Yujiの環境変数を設定し、自分のテレメトリが届くことを確認

### Phase 3: メンバー展開（Day 4）

- setup-member.sh の生成（terraform outputからIP取得）
- 5人のメンバーに展開
- 複数メンバーのデータが正しく区別されて表示されることを確認

### Phase 4: ダッシュボード作成（Day 5-6）

- claude-code-otel のデフォルトダッシュボードを参考にカスタマイズ
- メンバー別フィルターの追加
- スキル・MCP利用トレンドのパネル作成
- ダッシュボードJSONをエクスポートしてGitに保存

### Phase 5: /insights 収集の統合（Week 2、将来フェーズ）

- collect-insights.sh の作成
- extract-metrics.js の作成（HTML → JSON変換）
- VictoriaMetricsへのpush設定
- /insights 用Grafanaパネルの追加

### Phase 6: 運用定着（Week 3+）

- 週次レビューの習慣化
- 改善サイクルの実践
- ダッシュボードのレイアウト改善（フィードバック反映）

---

## 11. コスト

### 11.1 ランニングコスト

| 項目 | 月額 |
|------|------|
| GCE e2-micro (us-central1) | $0（Always Free） |
| 30GB Standard Persistent Disk | $0（Always Free） |
| 静的IPアドレス | $0（インスタンス稼働中） |
| ネットワーク（北米内 1GB/月） | $0（Always Free） |
| **合計** | **$0/月** |

### 11.2 将来のスケールアップ時

| シナリオ | 月額目安 |
|---------|---------|
| e2-small にアップグレード（2GB RAM） | ~$5/月 |
| Tokyoリージョン（asia-northeast1） | ~$7/月 |
| ディスク50GBに増量 | ~$1/月追加 |

### 11.3 将来のコスト最適化メモ（夜間VM自動停止）

**現状（Always Free 枠）では VM 停止は不要。** e2-micro は 720h/月（= 24/7）が無料のため、停止しても節約額は $0。さらに静的IPが VM 停止中に $0.01/時 課金されるため、逆にコストが増加する（8h/日停止で ~$2.40/月）。

将来 Always Free 枠を超えた場合（e2-small へのアップグレード、Tokyo リージョンへの移行等）は、夜間自動停止でコスト削減が可能：

| 方式 | 追加コスト | 複雑さ | 備考 |
|------|----------|--------|------|
| GCE Instance Schedule | $0 | 低 | Terraform `google_compute_resource_policy` で完結。推奨 |
| Cloud Scheduler → Compute API | $0（3ジョブ無料） | 低 | スケジュールから直接 API を呼ぶ |
| Cloud Scheduler → Cloud Functions | $0（無料枠内） | 中 | 関数のデプロイ・管理が必要。過剰 |

**節約効果の目安（16h/日 稼働 = 8:00-24:00）:**

| シナリオ | 24/7 | 16h/日 | 節約額 |
|---------|------|--------|--------|
| e2-small (2GB RAM) | ~$15/月 | ~$10/月 | ~$5/月 |
| Tokyo リージョン (e2-micro) | ~$7/月 | ~$4.70/月 | ~$2.30/月 |

> **Note:** 静的IPを削除して Tailscale MagicDNS のみでアクセスする構成にすれば、停止中の IP 課金も回避できる。

---

## 12. 技術リファレンス

| リソース | URL |
|---------|-----|
| claude-code-otel | https://github.com/ColeMurray/claude-code-otel |
| Claude Code Monitoring Guide | https://github.com/anthropics/claude-code-monitoring-guide |
| VictoriaMetrics ドキュメント | https://docs.victoriametrics.com/ |
| VictoriaLogs ドキュメント | https://docs.victoriametrics.com/victorialogs/ |
| Grafana ドキュメント | https://grafana.com/docs/grafana/latest/ |
| OpenTelemetry Collector | https://opentelemetry.io/docs/collector/ |
| GCP Always Free 枠 | https://cloud.google.com/free/docs/compute-getting-started |
| /insights 内部実装の解説 | https://www.zolkos.com/2026/02/04/deep-dive-how-claude-codes-insights-command-works.html |

---

## 13. 検討の末に採用しなかった選択肢

| 選択肢 | 不採用理由 |
|-------|-----------|
| Prometheus | メモリスパイクがe2-microでOOMリスク、Pushgateway別途必要 |
| Grafana Loki | 最低6-7GB RAM必要、e2-microでは動作不可能 |
| Cloud Run | ステートレス前提でデータ永続化不可、スケールゼロで常時受信不可、4サービスの localhost 連携不可、Tailscale デーモン維持不可、24/7 稼働で課金発生（詳細は 5.2 節） |
| GKE | 5人チームのダッシュボードにはオーバースペック |
| SigNoz / Uptrace | フルスタックAPMだがe2-microには重すぎる |
| Datadog | 有料、5人チームにはオーバースペック |
| Astro/Next.js ビューワー | Grafanaで十分、別アプリの管理コストが増える |
| ccusage CLI | 個人用ツール、チーム集約機能がない |
| 自宅Raspberry Pi サーバー | チームアクセスのネットワーク設定が複雑 |
| 公開HTTPでのポート全開放 | セキュリティリスクが高く、Tailscale VPN を採用して解消 |
