#!/bin/bash
# ============================================
# XAMPP Manual Respawn Trigger
# Usage: ./trigger-respawn.sh
# ============================================

WORKDIR="$HOME/.xampp-healthcheck"
TRIGGER_FILE="$WORKDIR/.trigger"

# Ensure working directory exists
if ! mkdir -p "$WORKDIR" 2>/dev/null; then
    echo "[x] Failed to create workdir: $WORKDIR"
    exit 1
fi

# Create trigger file
if touch "$TRIGGER_FILE" 2>/dev/null; then
    echo "[✓] Trigger created: $TRIGGER_FILE"
    echo "[✓] Watchdog will restart XAMPP on its next cycle."
else
    echo "[x] Failed to create trigger file: $TRIGGER_FILE"
    exit 1
fi