#!/bin/bash
# UserPromptSubmit hook: ターンIDを生成し、temp ファイルに書き込み + VictoriaLogs に送信
#
# 設定: .claude/settings.json の hooks.UserPromptSubmit（同期実行）
# 依存: jq (brew install jq)
#
# 仕組み:
#   1. ユーザーがプロンプトを送信すると発火
#   2. turn_id を生成し /tmp/claude-turn/{session_id}.turn_id に書き込み
#   3. PreToolUse Read hook (log-file-reads.sh) がこのファイルから turn_id を読み込む
#   4. VictoriaLogs に hook.user_turn イベントを送信（turn_id + プロンプト先頭200文字）

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')

if [ -z "$SESSION_ID" ]; then
  exit 0
fi

# turn_id 生成（session_id 先頭8文字 + Unix タイムスタンプ）
SHORT_SID=$(echo "$SESSION_ID" | cut -c1-8)
TURN_ID="${SHORT_SID}_$(date +%s)"

# temp ファイルに書き込み（PreToolUse hook が読む）
mkdir -p /tmp/claude-turn
echo "$TURN_ID" > "/tmp/claude-turn/${SESSION_ID}.turn_id"

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

JSON_PAYLOAD=$(jq -cn \
  --arg msg "user_turn: ${PROMPT}" \
  --arg time "$TIMESTAMP" \
  --arg event "hook.user_turn" \
  --arg tid "$TURN_ID" \
  --arg sid "$SESSION_ID" \
  --arg prompt "$PROMPT" \
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
    "user.name": $user,
    "project.name": $proj,
    "bu.name": $bu,
    "team.name": $team
  }')

# バックグラウンドで送信（Claude Code をブロックしない）
curl -s --max-time 2 -X POST \
  -H "Content-Type: application/stream+json" \
  --data-binary "$JSON_PAYLOAD" \
  "http://${OTEL_HOST}:9428/insert/jsonline" 2>/dev/null &

exit 0
