#!/bin/bash
# MCP Server Automated Cleanup Script
# Prevents disk space bloat by rotating old images, releases, and logs

set -e

DEPLOY_PATH="/root/mcp_project"
LOG_FILE="$DEPLOY_PATH/cleanup.log"

# Function to log with timestamp
log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)] $1" | tee -a "$LOG_FILE"
}

log "🧹 Starting automated cleanup process..."

# 1. Docker Images Cleanup (keep latest 3 timestamped images)
log "📦 Cleaning up old Docker images..."
OLD_IMAGES=$(docker images mcp-app --format '{{.Tag}}' | grep -E '^[0-9]{8}_[0-9]{6}$' | sort -r | tail -n +4 || echo "")
if [ -n "$OLD_IMAGES" ]; then
    echo "$OLD_IMAGES" | xargs -r -I {} docker rmi mcp-app:{} 2>/dev/null || true
    log "✅ Removed old Docker images: $(echo "$OLD_IMAGES" | tr '\n' ' ')"
else
    log "ℹ️ No old Docker images to remove"
fi

# 2. Remove dangling images
log "🗑️ Cleaning up dangling Docker images..."
DANGLING_COUNT=$(docker image prune -f --filter "dangling=true" 2>&1 | grep -o "deleted: [0-9]*" | cut -d: -f2 || echo "0")
log "✅ Removed $DANGLING_COUNT dangling images"

# 3. Release Directories Cleanup (keep latest 5)
log "📁 Cleaning up old release directories..."
if [ -d "$DEPLOY_PATH/releases" ]; then
    cd "$DEPLOY_PATH/releases"
    OLD_RELEASES=$(ls -1t 2>/dev/null | tail -n +6 || echo "")
    if [ -n "$OLD_RELEASES" ]; then
        echo "$OLD_RELEASES" | xargs -r rm -rf
        REMAINING=$(ls -1 | wc -l)
        log "✅ Removed old releases. Remaining: $REMAINING directories"
    else
        log "ℹ️ No old release directories to remove"
    fi
else
    log "⚠️ Release directory not found: $DEPLOY_PATH/releases"
fi

# 4. Log Rotation (keep last 200 entries)
log "📜 Rotating deployment logs..."
if [ -f "$DEPLOY_PATH/deployment.log" ]; then
    tail -n 200 "$DEPLOY_PATH/deployment.log" > "$DEPLOY_PATH/deployment.log.tmp"
    mv "$DEPLOY_PATH/deployment.log.tmp" "$DEPLOY_PATH/deployment.log"
    log "✅ Deployment log rotated (kept last 200 entries)"
fi

# 5. Cleanup log rotation (keep last 50 entries)
if [ -f "$LOG_FILE" ] && [ $(wc -l < "$LOG_FILE") -gt 100 ]; then
    tail -n 50 "$LOG_FILE" > "$LOG_FILE.tmp"
    mv "$LOG_FILE.tmp" "$LOG_FILE"
    echo "[$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)] ✅ Cleanup log rotated (kept last 50 entries)" >> "$LOG_FILE"
fi

# 6. System cleanup
log "🧽 Running system cleanup..."
# Clean package cache if available
if command -v apt-get >/dev/null 2>&1; then
    apt-get autoremove -y >/dev/null 2>&1 || true
    apt-get autoclean -y >/dev/null 2>&1 || true
fi

# 7. Display summary
log "📊 Cleanup Summary:"
log "  Docker Images: $(docker images mcp-app | wc -l) total"
log "  Release Dirs:  $(ls -1 $DEPLOY_PATH/releases 2>/dev/null | wc -l) total"
log "  Disk Usage:    $(df -h /root | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}')"

log "🎉 Automated cleanup completed successfully!"

# Optional: Send cleanup report via webhook (if configured)
if [ -n "${WEBHOOK_URL}" ]; then
    curl -X POST "${WEBHOOK_URL}" \
        -H "Content-Type: application/json" \
        -d "{\"text\":\"🧹 MCP Server cleanup completed. Disk usage: $(df -h /root | tail -1 | awk '{print $5}')\"}" \
        >/dev/null 2>&1 || true
fi