#!/bin/bash
# ============================================
# Auto Trigger - Auto restart on:
#   - No HTTP response
#   - No MySQL response
# ============================================

WORKDIR="$HOME/.xampp-healthcheck"
TRIGGER_FILE="$WORKDIR/.trigger"
PID_FILE="$WORKDIR/.trigger-auto.pid"
LOG="$WORKDIR/logs/trigger.log"
INTERVAL=20

mkdir -p "$WORKDIR/logs"

log() { echo "[$(date '+%F %T')] $1" >> "$LOG"; }

# Prevent duplicate instances
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "[-] trigger-auto is already running"
    exit 1
fi
echo $$ > "$PID_FILE"
trap 'log "[!] trigger-auto terminated"; rm -f "$PID_FILE"; exit 0' SIGTERM SIGINT

# HTTP check (with curl/wget fallback)
check_http() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsS --max-time 5 "http://localhost" > /dev/null 2>&1
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O /dev/null --timeout=5 "http://localhost" > /dev/null 2>&1
    else
        # No HTTP client available, assume OK to avoid false triggers
        return 0
    fi
}

# MySQL port check
check_mysql() {
    (echo > /dev/tcp/127.0.0.1/3306) > /dev/null 2>&1
}

# Track previous state to log only on change
http_was_down=0
mysql_was_down=0

log "[+] trigger-auto started (PID: $$)"

while true; do
    # --- HTTP check ---
    if ! check_http; then
        if [ "$http_was_down" -eq 0 ]; then
            log "[-] HTTP not responding!"
            http_was_down=1
        fi
        touch "$TRIGGER_FILE"
    else
        if [ "$http_was_down" -eq 1 ]; then
            log "[+] HTTP recovered"
            http_was_down=0
        fi
    fi

    # --- MySQL check ---
    if ! check_mysql; then
        if [ "$mysql_was_down" -eq 0 ]; then
            log "[-] MySQL not responding!"
            mysql_was_down=1
        fi
        touch "$TRIGGER_FILE"
    else
        if [ "$mysql_was_down" -eq 1 ]; then
            log "[+] MySQL recovered"
            mysql_was_down=0
        fi
    fi

    sleep "$INTERVAL"
done