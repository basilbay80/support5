#!/bin/bash
# ============================================
# XAMPP Helper Monitor - 2nd Layer Watchdog
# Role: Ensure main watchdog.sh keeps running
# ============================================

MAIN_WATCHDOG="$HOME/.xampp-healthcheck/watchdog.sh"
HELPER_DIR="/tmp/.xampp-helper"
PID_FILE="$HELPER_DIR/.monitor.pid"
LOG_FILE="$HELPER_DIR/monitor.log"
LOCK_FILE="$HELPER_DIR/.watchdog.lock"
INTERVAL=30

mkdir -p "$HELPER_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [MONITOR] $1" >> "$LOG_FILE"
}

# Check if main watchdog is running (specific to full path)
is_watchdog_running() {
    pgrep -f "$MAIN_WATCHDOG" > /dev/null
}

# Restart main watchdog (with lock to prevent double-spawn)
respawn_watchdog() {
    log "[!] Main watchdog is dead. Restarting..."

    if [ ! -f "$MAIN_WATCHDOG" ]; then
        log "[x] Watchdog file not found: $MAIN_WATCHDOG"
        return
    fi

    # Prevent race condition with guard.sh
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
        log "[~] Another process is already restarting watchdog. Skipping."
        return
    fi

    # Re-check after acquiring lock (in case guard.sh already restarted it)
    if is_watchdog_running; then
        log "[~] Watchdog already restarted by another layer. Skipping."
        return
    fi

    chmod +x "$MAIN_WATCHDOG"
    nohup bash "$MAIN_WATCHDOG" > /dev/null 2>&1 &
    log "[✓] Main watchdog restarted (PID: $!)"
}

# Main loop
main() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "[-] Monitor is already running"
        exit 1
    fi

    echo $$ > "$PID_FILE"
    log "========================================"
    log "[+] Monitor started (PID: $$)"
    log "========================================"

    trap 'log "[!] Monitor terminated"; rm -f "$PID_FILE"; exit 0' SIGTERM SIGINT

    while true; do
        if ! is_watchdog_running; then
            respawn_watchdog
        fi
        sleep "$INTERVAL"
    done
}

main "$@"