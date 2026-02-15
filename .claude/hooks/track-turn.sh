#!/bin/bash
# UserPromptSubmit hook: ターンIDを生成 + user_turn イベントを送信
#
# 設定: .claude/settings.json の hooks.UserPromptSubmit（同期実行）
# 依存: jq (brew install jq)
#
# 仕組み:
#   1. ユーザーがプロンプトを送信すると発火
#   2. 新しい turn_id を生成し temp ファイルに書き込み
#      （Stop hook の stop-turn.sh と PreToolUse hook の log-file-reads.sh が参照）
#   3. user_turn イベントを VictoriaLogs に送信

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')

if [ -z "$SESSION_ID" ]; then
  exit 0
fi

# OTEL エンドポイントからホスト名を導出（例: http://my-host:4317 → my-host）
OTEL_HOST=$(echo "${OTEL_EXPORTER_OTLP_ENDPOINT:-}" | sed 's|.*://||;s|:.*||')
if [ -z "$OTEL_HOST" ]; then
  exit 0
fi

# OTEL_RESOURCE_ATTRIBUTES から属性を抽出
USER_NAME=$(echo "${OTEL_RESOURCE_ATTRIBUTES:-}" | grep -o 'user\.name=[^,]*' | cut -d= -f2)
PROJECT_NAME=$(echo "${OTEL_RESOURCE_ATTRIBUTES:-}" | grep -o 'project\.name=[^,]*' | cut -d= -f2)
BU_NAME=$(echo "${OTEL_RESOURCE_ATTRIBUTES:-}" | grep -o 'bu\.name=[^,]*' | cut -d= -f2)
TEAM_NAME=$(echo "${OTEL_RESOURCE_ATTRIBUTES:-}" | grep -o 'team\.name=[^,]*' | cut -d= -f2)

TIMESTAMP=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
TURN_DIR="/tmp/claude-turn"
VLOGS_URL="http://${OTEL_HOST}:9428"
mkdir -p "$TURN_DIR"

# === 新しいターンの turn_id を生成し temp ファイルに書き込み ===
# （Stop hook と PreToolUse hook が読むため、イベント送信より先に書く）
SHORT_SID=$(echo "$SESSION_ID" | cut -c1-8)
TURN_ID="${SHORT_SID}_$(date +%s)"

echo "$TURN_ID" > "${TURN_DIR}/${SESSION_ID}.turn_id"
printf '%s' "$PROMPT" > "${TURN_DIR}/${SESSION_ID}.prompt"
echo "$TIMESTAMP" > "${TURN_DIR}/${SESSION_ID}.turn_time"

# スラッシュコマンドの抽出（例: "/hogehoge 引数" → "hogehoge"）
SLASH_COMMAND=""
if echo "$PROMPT" | grep -qE '^\s*/[a-zA-Z]'; then
  SLASH_COMMAND=$(echo "$PROMPT" | sed 's/^[[:space:]]*//' | cut -d' ' -f1 | sed 's|^/||')
fi

# === user_turn イベントを即送信 ===
(
  JSON_PAYLOAD=$(jq -cn \
    --arg msg "user_turn: ${PROMPT}" \
    --arg time "$TIMESTAMP" \
    --arg event "hook.user_turn" \
    --arg tid "$TURN_ID" \
    --arg sid "$SESSION_ID" \
    --arg prompt "$PROMPT" \
    --arg slash "$SLASH_COMMAND" \
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
      "prompt": $prompt,
      "slash_command": $slash,
      "user.name": $user,
      "project.name": $proj,
      "bu.name": $bu,
      "team.name": $team
    }')

  curl -s --max-time 2 -X POST \
    -H "Content-Type: application/stream+json" \
    --data-binary "$JSON_PAYLOAD" \
    "${VLOGS_URL}/insert/jsonline" 2>/dev/null
) &

exit 0
