#!/bin/bash
# Stop hook: Claude 返答完了時にターン別トークン消費を集計して送信
#
# 設定: .claude/settings.json の hooks.Stop（async 実行）
# 依存: jq (brew install jq)
#
# 仕組み:
#   1. Claude が返答を完了すると発火
#   2. temp ファイルからターン情報（turn_id, prompt, 開始時刻）を読み込み
#   3. 20秒待機（OTEL Collector バッチフラッシュ待ち）
#   4. VictoriaLogs に時間ウィンドウクエリ: [ターン開始, Stop時刻] の api_request を集計
#   5. hook.turn_complete イベントを VictoriaLogs に送信
#
# 利点:
#   - ターン完了時に自然にデータ取得（次のプロンプト不要）
#   - 最後のターンも自動的に記録される
#   - cost_usd は OTEL api_request 由来で正確（料金表メンテ不要）

INPUT=$(cat)

# 無限ループ防止: Stop hook が自分自身の出力で再発火した場合
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
if [ -z "$SESSION_ID" ]; then
  exit 0
fi

# OTEL エンドポイントからホスト名を導出
OTEL_HOST=$(echo "${OTEL_EXPORTER_OTLP_ENDPOINT:-}" | sed 's|.*://||;s|:.*||')
if [ -z "$OTEL_HOST" ]; then
  exit 0
fi

# OTEL_RESOURCE_ATTRIBUTES から属性を抽出
USER_NAME=$(echo "${OTEL_RESOURCE_ATTRIBUTES:-}" | grep -o 'user\.name=[^,]*' | cut -d= -f2)
PROJECT_NAME=$(echo "${OTEL_RESOURCE_ATTRIBUTES:-}" | grep -o 'project\.name=[^,]*' | cut -d= -f2)
BU_NAME=$(echo "${OTEL_RESOURCE_ATTRIBUTES:-}" | grep -o 'bu\.name=[^,]*' | cut -d= -f2)
TEAM_NAME=$(echo "${OTEL_RESOURCE_ATTRIBUTES:-}" | grep -o 'team\.name=[^,]*' | cut -d= -f2)

TURN_DIR="/tmp/claude-turn"
VLOGS_URL="http://${OTEL_HOST}:9428"

# temp ファイルからターン情報を読み込み
TURN_ID=$(cat "${TURN_DIR}/${SESSION_ID}.turn_id" 2>/dev/null || echo "")
PROMPT=$(cat "${TURN_DIR}/${SESSION_ID}.prompt" 2>/dev/null || echo "")
TURN_START=$(cat "${TURN_DIR}/${SESSION_ID}.turn_time" 2>/dev/null || echo "")

if [ -z "$TURN_ID" ] || [ -z "$TURN_START" ]; then
  exit 0
fi

# Stop 時刻を記録（ターン終了時刻）
STOP_TIME=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

# OTEL Collector のバッチフラッシュを待つ（10秒バッチ間隔 + バッファ）
sleep 20

# VictoriaLogs クエリ: このターンの時間ウィンドウ内の api_request を集計
STATS=$(curl -s --max-time 10 \
  "${VLOGS_URL}/select/logsql/query" \
  --data-urlencode "query=event.name:api_request AND \"session.id\":\"${SESSION_ID}\" | stats sum(input_tokens) as input_tokens, sum(output_tokens) as output_tokens, sum(cache_read_tokens) as cache_read_tokens, sum(cost_usd) as cost_usd, count(*) as api_calls" \
  -d "start=${TURN_START}" \
  -d "end=${STOP_TIME}" \
  2>/dev/null)
STATS=${STATS:-'{}'}

INPUT_TOKENS=$(echo "$STATS" | jq -r '.input_tokens // "0"')
OUTPUT_TOKENS=$(echo "$STATS" | jq -r '.output_tokens // "0"')
CACHE_TOKENS=$(echo "$STATS" | jq -r '.cache_read_tokens // "0"')
COST_USD=$(echo "$STATS" | jq -r '.cost_usd // "0"')
API_CALLS=$(echo "$STATS" | jq -r '.api_calls // "0"')

# api_request が0件の場合はスキップ（データなし）
if [ "$API_CALLS" = "0" ]; then
  exit 0
fi

# hook.turn_complete イベントを送信
COMPLETE_PAYLOAD=$(jq -cn \
  --arg msg "turn_complete: ${PROMPT:0:200}" \
  --arg time "$STOP_TIME" \
  --arg event "hook.turn_complete" \
  --arg tid "$TURN_ID" \
  --arg sid "$SESSION_ID" \
  --arg tstart "$TURN_START" \
  --arg prompt "$PROMPT" \
  --arg input "$INPUT_TOKENS" \
  --arg output "$OUTPUT_TOKENS" \
  --arg cache "$CACHE_TOKENS" \
  --arg cost "$COST_USD" \
  --arg calls "$API_CALLS" \
  --arg user "$USER_NAME" \
  --arg proj "$PROJECT_NAME" \
  --arg bu "$BU_NAME" \
  --arg team "$TEAM_NAME" \
  '{
    "_msg": $msg,
    "_time": $time,
    "event.name": $event,
    "turn_id": $tid,
    "session_id": $sid,
    "turn_start": $tstart,
    "prompt": $prompt,
    "input_tokens": $input,
    "output_tokens": $output,
    "cache_read_tokens": $cache,
    "cost_usd": $cost,
    "api_calls": $calls,
    "user.name": $user,
    "project.name": $proj,
    "bu.name": $bu,
    "team.name": $team
  }')

curl -s --max-time 2 -X POST \
  -H "Content-Type: application/stream+json" \
  --data-binary "$COMPLETE_PAYLOAD" \
  "${VLOGS_URL}/insert/jsonline" 2>/dev/null

exit 0
