#!/bin/bash
# ============================================================
# Claude Code Team Dashboard - メンバーセットアップスクリプト
#
# 使い方:
#   1. terraform output -raw member_env_vars でIPを確認
#   2. このスクリプトの DASHBOARD_IP を更新
#   3. メンバーに配布して実行してもらう
# ============================================================

set -euo pipefail

DASHBOARD_IP="__REPLACE_WITH_TERRAFORM_OUTPUT__"

# Detect shell config file
if [ -f "$HOME/.zshrc" ]; then
  SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
  SHELL_RC="$HOME/.bashrc"
else
  echo "Error: .zshrc or .bashrc not found"
  exit 1
fi

# Check if already configured
if grep -q "CLAUDE_CODE_ENABLE_TELEMETRY" "$SHELL_RC" 2>/dev/null; then
  echo "⚠️  Already configured in $SHELL_RC"
  echo "   To reconfigure, remove the '# === Claude Code Team Dashboard ===' block first."
  exit 0
fi

# Add environment variables
cat >> "$SHELL_RC" << EOF

# === Claude Code Team Dashboard ===
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT=http://${DASHBOARD_IP}:4317
export OTEL_LOG_TOOL_DETAILS=1
EOF

echo "✅ Added to $SHELL_RC"
echo ""
echo "Run the following to apply:"
echo "  source $SHELL_RC"
echo ""
echo "Dashboard: http://${DASHBOARD_IP}:3000"
echo ""
echo "To verify telemetry is being sent, start a Claude Code session"
echo "and check the dashboard after a few minutes."
