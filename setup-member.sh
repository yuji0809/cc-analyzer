#!/bin/bash
# ============================================================
# Claude Code Team Dashboard - メンバーセットアップスクリプト
#
# 対象リポジトリのルートで実行すると、
# .claude/settings.local.json を作成（または更新）する。
#
# settings.json の OTEL_RESOURCE_ATTRIBUTES（project.name, bu.name,
# team.name）を引き継ぎ、user.name を追加してマージする。
#
# 使い方:
#   cd /path/to/target-repo
#   /path/to/cc-analyzer/setup-member.sh
# ============================================================

set -euo pipefail

SHARED_SETTINGS=".claude/settings.json"
LOCAL_SETTINGS=".claude/settings.local.json"

if [ ! -f "$SHARED_SETTINGS" ]; then
  echo "Error: $SHARED_SETTINGS not found in current directory."
  echo "This script must be run from a repository that has $SHARED_SETTINGS configured."
  exit 1
fi

# Read shared OTEL_RESOURCE_ATTRIBUTES from settings.json
SHARED_ATTRS=$(jq -r '.env.OTEL_RESOURCE_ATTRIBUTES // empty' "$SHARED_SETTINGS")

# Read existing user.name from local settings (if file exists)
EXISTING_USER=""
if [ -f "$LOCAL_SETTINGS" ]; then
  echo "Existing configuration found: $LOCAL_SETTINGS"
  EXISTING_ATTRS=$(jq -r '.env.OTEL_RESOURCE_ATTRIBUTES // empty' "$LOCAL_SETTINGS")
  EXISTING_USER=$(echo "$EXISTING_ATTRS" | grep -o 'user\.name=[^,]*' | cut -d= -f2 || true)
  echo ""
fi

# Get user name (= Grafana login email)
# "自分のビュー" link uses ${__user.login} (Grafana login email) to filter by user.
# user.name must match the Grafana login email for the link to work.
DEFAULT_NAME="${EXISTING_USER:-}"
read -rp "Enter your Grafana login email (e.g. taro@example.com) [$DEFAULT_NAME]: " USER_NAME
USER_NAME="${USER_NAME:-$DEFAULT_NAME}"

if [ -z "$USER_NAME" ]; then
  echo "Error: Name cannot be empty."
  exit 1
fi

# Merge: shared attributes + user.name
NEW_ATTRS="${SHARED_ATTRS},user.name=${USER_NAME}"

# Create or update .claude/settings.local.json (preserve other settings)
if [ -f "$LOCAL_SETTINGS" ]; then
  jq --arg attrs "$NEW_ATTRS" '.env.OTEL_RESOURCE_ATTRIBUTES = $attrs' "$LOCAL_SETTINGS" > "${LOCAL_SETTINGS}.tmp"
  mv "${LOCAL_SETTINGS}.tmp" "$LOCAL_SETTINGS"
  echo "Updated: $LOCAL_SETTINGS"
else
  cat > "$LOCAL_SETTINGS" << EOF
{
  "env": {
    "OTEL_RESOURCE_ATTRIBUTES": "${NEW_ATTRS}"
  }
}
EOF
  echo "Created: $LOCAL_SETTINGS"
fi

echo ""
echo "  OTEL_RESOURCE_ATTRIBUTES: $NEW_ATTRS"
echo ""

# Suggest adding to .gitignore if not already there
if ! grep -q "settings.local.json" .gitignore 2>/dev/null; then
  echo "Tip: Add the following to .gitignore:"
  echo "  .claude/settings.local.json"
fi
