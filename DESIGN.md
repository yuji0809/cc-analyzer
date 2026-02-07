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
- **セッション品質の傾向分析**: 成功率、満足度、フリクション（摩擦）の推移
- **チーム比較**: メンバー間の利用パターンの違いを発見し、ベストプラクティスを共有

### 1.3 期待される効果

- チーム全体のClaude Code活用水準の底上げ
- 「誰も使っていないスキルやMCPサーバー」の発見と啓蒙
- 改善施策（スキルファイルの改善、MCPの追加等）のPDCA高速化
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
      │                                               │
      ▼                                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                 GCE e2-micro (us-central1)                       │
│                 GCP Always Free 枠                               │
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
└────────────────────────────────────│────────────────────────────┘
                                     │
                              メンバーがブラウザで閲覧
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

### 5.2 メモリ配分

e2-micro の 1GB RAM で 4 コンテナを動かすためのメモリ計画。

| コンポーネント | メモリ上限設定 | 備考 |
|-------------|-------------|------|
| OTEL Collector | ~100MB | 軽量、受信のみ |
| VictoriaMetrics | ~100-150MB | メモリ消費が安定（スパイクなし） |
| VictoriaLogs | ~100-150MB | シングルバイナリ、ゼロコンフィグ |
| Grafana | ~150-200MB | ダッシュボード描画 |
| OS + Docker | ~200MB | - |
| swap | 1-2GB | ピーク時のバッファ |
| **合計** | **~650-850MB** | 1GB以内に収まる |

startup.sh で 1-2GB の swapfile を作成し、ピーク時のOOMを防止する。

### 5.3 セキュリティ（お試しフェーズ）

本格運用ではなくお試しフェーズのため、最低限の対策のみ実施。

| 対策 | 内容 |
|------|------|
| Grafana認証 | 初回ログイン時にデフォルトパスワード (admin/admin) を変更 |
| SSH制限 | GCPファイアウォールで :22 をYujiのIPのみに制限 |
| :4317 / :3000 | 全開放（攻撃リスクは極めて低い） |

**本格運用移行時の追加対策（将来）:**

- Tailscale（無料枠100台）によるプライベートネットワーク化
- OTEL Collector へのBearerトークン認証追加
- 全ポートをTailscale内に閉じる

### 5.4 ディスク管理

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

### 6.1 各メンバーが設定する環境変数

以下を `.zshrc` または `.bashrc` に追加する。

```bash
# Claude Code テレメトリ送信の有効化
export CLAUDE_CODE_ENABLE_TELEMETRY=1

# OTEL 送信設定
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT=http://<GCE_STATIC_IP>:4317

# ツール詳細ログの有効化（MCP名・スキル名を取得するために必須）
export OTEL_LOG_TOOL_DETAILS=1
```

### 6.2 セットアップスクリプト

`terraform output` から GCE の静的IPを取得し、上記の環境変数を自動的に `.zshrc` に追記するセットアップスクリプトを提供する。

```bash
# メンバーは以下を実行するだけ
./setup-member.sh
source ~/.zshrc
```

---

## 7. 使い方・運用ガイド

### 7.1 日常の使い方

メンバーは特に意識することなく、通常通りClaude Codeを使うだけでよい。テレメトリは環境変数設定後、自動的にバックグラウンドで送信される。

**ダッシュボードの確認:**

1. ブラウザで `http://<GCE_STATIC_IP>:3000` を開く
2. Grafanaにログイン
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
terraform/
  ├── main.tf          # provider設定、GCPプロジェクト
  ├── variables.tf     # 変数定義（リージョン、プロジェクトID等）
  ├── gce.tf           # GCE インスタンス定義
  ├── firewall.tf      # ファイアウォールルール
  ├── outputs.tf       # 出力値（静的IP、接続コマンド等）
  ├── terraform.tfvars # 変数値（.gitignoreに追加）
  └── startup.sh       # インスタンス起動時の自動セットアップ
```

### 8.2 Docker Compose による全サービス管理

GCEインスタンス上で Docker Compose により4つのコンテナを管理する。

```
docker/
  ├── docker-compose.yml         # 全コンテナ定義
  ├── otel-collector-config.yaml # OTEL Collector設定
  ├── victoria-metrics.yml       # VictoriaMetrics設定（必要に応じて）
  └── grafana/
      └── provisioning/
          ├── datasources/
          │   └── datasources.yml    # VictoriaMetrics/Logsを自動登録
          └── dashboards/
              ├── dashboards.yml     # ダッシュボードプロビジョニング設定
              └── team-dashboard.json # ダッシュボードJSON（Gitで管理）
```

### 8.3 Grafana ダッシュボードのバックアップ

Grafanaのダッシュボードは内部的にJSONで構成されている。GUIで作成したダッシュボードをJSONエクスポートし、Gitリポジトリに保存する。

`terraform destroy` → `terraform apply` でGCEを再構築した場合でも、Grafanaが起動時にprovisioning ディレクトリのJSONを自動読み込みするため、ダッシュボードが自動復元される。

---

## 9. リポジトリ構成

```
claude-code-team-dashboard/
  ├── README.md                        # セットアップ手順
  ├── DESIGN.md                        # 本設計書
  ├── terraform/
  │   ├── main.tf
  │   ├── variables.tf
  │   ├── gce.tf
  │   ├── firewall.tf
  │   ├── outputs.tf
  │   ├── terraform.tfvars             # (.gitignore)
  │   └── startup.sh
  ├── docker/
  │   ├── docker-compose.yml
  │   ├── otel-collector-config.yaml
  │   └── grafana/
  │       └── provisioning/
  │           ├── datasources/
  │           │   └── datasources.yml
  │           └── dashboards/
  │               ├── dashboards.yml
  │               └── team-dashboard.json
  ├── scripts/
  │   ├── setup-member.sh.tpl          # メンバー環境変数セットアップ
  │   ├── collect-insights.sh          # /insights収集スクリプト（将来フェーズ）
  │   └── extract-metrics.js           # HTML→JSON変換（将来フェーズ）
  └── .gitignore
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
| Cloud Run | ステートフルサービス（DB）と相性が悪い、常時起動コスト |
| GKE | 5人チームのダッシュボードにはオーバースペック |
| SigNoz / Uptrace | フルスタックAPMだがe2-microには重すぎる |
| Datadog | 有料、5人チームにはオーバースペック |
| Astro/Next.js ビューワー | Grafanaで十分、別アプリの管理コストが増える |
| ccusage CLI | 個人用ツール、チーム集約機能がない |
| 自宅Raspberry Pi サーバー | チームアクセスのネットワーク設定が複雑 |
| Tailscale（お試しフェーズ） | 本格運用時に導入で十分、全員インストールの手間 |
