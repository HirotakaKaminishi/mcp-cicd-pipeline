#!/bin/bash
# Install cleanup script as a cron job on MCP server
# This script should be run once to set up automated cleanup

set -e

SCRIPT_DIR="/root/mcp_scripts"
CLEANUP_SCRIPT="$SCRIPT_DIR/cleanup.sh"

echo "🔧 Installing MCP Server cleanup automation..."

# Create scripts directory
mkdir -p "$SCRIPT_DIR"

# Copy cleanup script (this should be deployed via CI/CD)
if [ -f "/tmp/cleanup.sh" ]; then
    cp "/tmp/cleanup.sh" "$CLEANUP_SCRIPT"
    chmod +x "$CLEANUP_SCRIPT"
    echo "✅ Cleanup script installed at $CLEANUP_SCRIPT"
else
    echo "❌ Cleanup script not found at /tmp/cleanup.sh"
    exit 1
fi

# Install cron job (runs every day at 2 AM)
CRON_JOB="0 2 * * * $CLEANUP_SCRIPT >/dev/null 2>&1"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "$CLEANUP_SCRIPT"; then
    echo "ℹ️ Cron job already exists for cleanup script"
else
    # Add cron job
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "✅ Cron job installed: Daily cleanup at 2:00 AM"
fi

# Install weekly comprehensive cleanup (runs every Sunday at 3 AM)
WEEKLY_CRON="0 3 * * 0 $CLEANUP_SCRIPT && docker system prune -a -f --volumes >/dev/null 2>&1"

if crontab -l 2>/dev/null | grep -q "docker system prune"; then
    echo "ℹ️ Weekly comprehensive cleanup already exists"
else
    (crontab -l 2>/dev/null; echo "$WEEKLY_CRON") | crontab -
    echo "✅ Weekly comprehensive cleanup installed: Sundays at 3:00 AM"
fi

# Display current cron jobs
echo ""
echo "📋 Current cron jobs:"
crontab -l | grep -E "(cleanup|prune)" || echo "No cleanup cron jobs found"

# Test run the cleanup script
echo ""
echo "🧪 Running test cleanup..."
"$CLEANUP_SCRIPT"

echo ""
echo "🎉 Cleanup automation installation completed!"
echo "📅 Schedule:"
echo "  - Daily cleanup: 2:00 AM (images, releases, logs)"
echo "  - Weekly full cleanup: Sunday 3:00 AM (+ system prune)"
echo ""
echo "💡 To manually run cleanup: $CLEANUP_SCRIPT"
echo "💡 To view cleanup logs: tail -f /root/mcp_project/cleanup.log"