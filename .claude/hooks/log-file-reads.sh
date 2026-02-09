#!/bin/bash
# Claude Code PreToolUse hook: Read ツール呼び出し時にファイルパスを VictoriaLogs に送信
#
# 設定: .claude/settings.json の hooks.PreToolUse で matcher: "Read", async: true として登録
# 依存: jq (brew install jq)

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

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

# ファイル拡張子を抽出（フィルター用）
FILE_EXT=".${FILE_PATH##*.}"
if [ "$FILE_EXT" = ".$FILE_PATH" ]; then
  FILE_EXT=""
fi

FILE_NAME=$(basename "$FILE_PATH")

TIMESTAMP=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

# turn_id を temp ファイルから読み込み（UserPromptSubmit hook が書き込む）
TURN_ID=$(cat "/tmp/claude-turn/${SESSION_ID}.turn_id" 2>/dev/null || echo "")

# jq で1行の JSON を構築（VictoriaLogs JSON Lines API は1行1JSONを要求）
JSON_PAYLOAD=$(jq -cn \
  --arg msg "file_read: ${FILE_PATH}" \
  --arg time "$TIMESTAMP" \
  --arg event "hook.file_read" \
  --arg fp "$FILE_PATH" \
  --arg ext "$FILE_EXT" \
  --arg fname "$FILE_NAME" \
  --arg sid "$SESSION_ID" \
  --arg tid "$TURN_ID" \
  --arg user "$USER_NAME" \
  --arg proj "$PROJECT_NAME" \
  --arg bu "$BU_NAME" \
  --arg team "$TEAM_NAME" \
  --arg cwd "$CWD" \
  '{
    "_msg": $msg,
    "_time": $time,
    "event.name": $event,
    "file_path": $fp,
    "file_extension": $ext,
    "file_name": $fname,
    "session_id": $sid,
    "turn_id": $tid,
    "user.name": $user,
    "project.name": $proj,
    "bu.name": $bu,
    "team.name": $team,
    "cwd": $cwd
  }')

# VictoriaLogs に送信（2秒タイムアウト、失敗しても Claude Code をブロックしない）
curl -s --max-time 2 -X POST \
  -H "Content-Type: application/stream+json" \
  --data-binary "$JSON_PAYLOAD" \
  "http://${OTEL_HOST}:9428/insert/jsonline" 2>/dev/null || true

exit 0
