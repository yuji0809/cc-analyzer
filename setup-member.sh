#!/bin/bash
# ============================================================
# Claude Code Team Dashboard - メンバーセットアップスクリプト
#
# 対象リポジトリのルートで実行すると、
# .claude/settings.local.json を作成する。
#
# 使い方:
#   cd /path/to/target-repo
#   /path/to/cc-analyzer/setup-member.sh
# ============================================================

set -euo pipefail

# Check if .claude/settings.json exists (confirms this is a configured repo)
if [ ! -f ".claude/settings.json" ]; then
  echo "Error: .claude/settings.json not found in current directory."
  echo "This script must be run from a repository that has .claude/settings.json configured."
  exit 1
fi

LOCAL_SETTINGS=".claude/settings.local.json"

# Check if already configured
if [ -f "$LOCAL_SETTINGS" ]; then
  echo "Already configured: $LOCAL_SETTINGS"
  echo "To reconfigure, delete the file first."
  exit 0
fi

# Get user name (default to OS username)
DEFAULT_NAME="${USER:-$(whoami)}"
read -rp "Enter your display name for the dashboard [$DEFAULT_NAME]: " USER_NAME
USER_NAME="${USER_NAME:-$DEFAULT_NAME}"

if [ -z "$USER_NAME" ]; then
  echo "Error: Name cannot be empty."
  exit 1
fi

# Derive project name from directory
PROJECT_NAME=$(basename "$(pwd)")

# Create .claude/settings.local.json
cat > "$LOCAL_SETTINGS" << EOF
{
  "env": {
    "OTEL_RESOURCE_ATTRIBUTES": "user.name=${USER_NAME},project.name=${PROJECT_NAME}"
  }
}
EOF

echo "Created: $LOCAL_SETTINGS"
echo ""
echo "  user.name:    $USER_NAME"
echo "  project.name: $PROJECT_NAME"
echo ""

# Suggest adding to .gitignore if not already there
if ! grep -q "settings.local.json" .gitignore 2>/dev/null; then
  echo "Tip: Add the following to .gitignore:"
  echo "  .claude/settings.local.json"
fi
