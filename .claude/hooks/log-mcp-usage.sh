#!/bin/bash
# Claude Code PreToolUse hook: MCP ツール呼び出し時にサーバー名・ツール名を VictoriaLogs に送信
#
# 設定: .claude/settings.json の hooks.PreToolUse で matcher: "mcp__.*", async: true として登録
# 依存: jq (brew install jq)
#
# MCP ツール名の形式: mcp__<server_name>__<tool_name>
# 例: mcp__plugin_serena_serena__find_symbol → server=plugin_serena_serena, tool=find_symbol

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
if [ -z "$TOOL_NAME" ]; then
  exit 0
fi

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# MCP ツール名をパース: mcp__<server>__<tool>
STRIPPED="${TOOL_NAME#mcp__}"
MCP_SERVER="${STRIPPED%%__*}"
MCP_TOOL="${STRIPPED#*__}"

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

# turn_id を temp ファイルから読み込み
TURN_ID=$(cat "/tmp/claude-turn/${SESSION_ID}.turn_id" 2>/dev/null || echo "")

JSON_PAYLOAD=$(jq -cn \
  --arg msg "mcp_use: ${MCP_SERVER}/${MCP_TOOL}" \
  --arg time "$TIMESTAMP" \
  --arg event "hook.mcp_use" \
  --arg server "$MCP_SERVER" \
  --arg tool "$MCP_TOOL" \
  --arg sid "$SESSION_ID" \
  --arg tid "$TURN_ID" \
  --arg user "$USER_NAME" \
  --arg proj "$PROJECT_NAME" \
  --arg bu "$BU_NAME" \
  --arg team "$TEAM_NAME" \
  '{
    "_msg": $msg,
    "_time": $time,
    "event.name": $event,
    "mcp_server_name": $server,
    "mcp_tool_name": $tool,
    "session_id": $sid,
    "turn_id": $tid,
    "user.name": $user,
    "project.name": $proj,
    "bu.name": $bu,
    "team.name": $team
  }')

curl -s --max-time 2 -X POST \
  -H "Content-Type: application/stream+json" \
  --data-binary "$JSON_PAYLOAD" \
  "http://${OTEL_HOST}:9428/insert/jsonline" 2>/dev/null || true

exit 0
