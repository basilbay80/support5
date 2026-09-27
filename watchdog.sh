#!/bin/bash
# ============================================
# XAMPP Watchdog - Auto Restart Monitor
# Monitors: XAMPP (Apache+MySQL) and worker (kernelU)
# ============================================

WORKDIR="$HOME/.xampp-healthcheck"
XAMPP_DIR="$HOME/xampp"
XAMPP_BIN="$XAMPP_DIR/lampp/lampp"
WORKER_BIN="$WORKDIR/kernelU"

LOG_FILE="$WORKDIR/logs/watchdog.log"
PID_FILE="$WORKDIR/.watchdog.pid"
TRIGGER_FILE="$WORKDIR/.trigger"
LOCK_FILE="$WORKDIR/.watchdog.lock"

INTERVAL=15          # check every 15s
XAMPP_START_WAIT=6   # wait after starting XAMPP

mkdir -p "$WORKDIR/logs"

# ============================================
# Logging
# ============================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# ============================================
# Check if XAMPP (Apache + MySQL) is running
# ============================================
is_xampp_running() {
    pgrep -x httpd > /dev/null 2>&1 || pgrep -x apache2 > /dev/null 2>&1
    local apache=$?
    pgrep -x mysqld > /dev/null 2>&1
    local mysql=$?
    [ "$apache" -eq 0 ] && [ "$mysql" -eq 0 ]
}

# ============================================
# Check if worker (kernelU) is running
# ============================================
is_worker_running() {
    pgrep -f "$WORKER_BIN" > /dev/null 2>&1
}

# ============================================
# Start XAMPP (non-interactive sudo)
# ============================================
start_xampp() {
    if [ ! -x "$XAMPP_BIN" ]; then
        log "[x] XAMPP binary not found or not executable: $XAMPP_BIN"
        return 1
    fi

    log "[+] XAMPP is down. Attempting to start..."
    sudo -n "$XAMPP_BIN" start >> "$LOG_FILE" 2>&1
    sleep "$XAMPP_START_WAIT"

    if is_xampp_running; then
        log "[✓] XAMPP started successfully"
        return 0
    else
        log "[x] XAMPP start failed. Will retry later."
        return 1
    fi
}

# ============================================
# Stop XAMPP (non-interactive sudo)
# ============================================
stop_xampp() {
    log "[!] Stopping XAMPP..."
    sudo -n "$XAMPP_BIN" stop >> "$LOG_FILE" 2>&1
    sleep 2
    log "[✓] XAMPP stopped"
}

# ============================================
# Start worker (kernelU)
# ============================================
start_worker() {
    if [ ! -x "$WORKER_BIN" ]; then
        log "[x] Worker binary not found: $WORKER_BIN"
        return 1
    fi

    log "[+] Worker is down. Starting..."
    cd "$WORKDIR"
    nohup "$WORKER_BIN" >> "$WORKDIR/logs/runner.log" 2>&1 &
    sleep 2

    if is_worker_running; then
        log "[✓] Worker started (PID: $!)"
        return 0
    else
        log "[x] Worker start failed."
        return 1
    fi
}

# ============================================
# Handle trigger file (force restart)
# ============================================
check_trigger() {
    if [ ! -f "$TRIGGER_FILE" ]; then
        return 1
    fi

    log "[!] Trigger detected! Forcing restart..."

    # Lock to avoid race with other layers
    exec 9>"$LOCK_FILE"
    if command -v flock >/dev/null 2>&1; then
        if ! flock -n 9; then
            log "[~] Another process handling trigger. Skipping."
            return 0
        fi
    fi

    # Remove trigger first (idempotent even if restart fails)
    rm -f "$TRIGGER_FILE"

    # Restart XAMPP
    if is_xampp_running; then
        stop_xampp
        sleep 2
    fi
    start_xampp

    # Restart worker
    if is_worker_running; then
        pkill -f "$WORKER_BIN"
        sleep 1
    fi
    start_worker

    return 0
}

# ============================================
# Main loop
# ============================================
main() {
    # Prevent duplicate instances
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "[-] Watchdog already running (PID: $(cat "$PID_FILE"))"
        exit 1
    fi

    echo $$ > "$PID_FILE"
    log "========================================"
    log "[+] Watchdog started (PID: $$)"
    log "[+] Interval: ${INTERVAL}s"
    log "========================================"

    trap 'log "[!] Watchdog terminated"; rm -f "$PID_FILE"; exit 0' SIGTERM SIGINT

    while true; do
        # 1. Handle manual trigger
        if check_trigger; then
            sleep "$INTERVAL"
            continue
        fi

        # 2. Ensure XAMPP running
        if ! is_xampp_running; then
            log "[-] XAMPP detected as stopped"
            for i in 1 2 3; do
                log "[+] Start attempt #$i"
                if start_xampp; then
                    break
                fi
                sleep 5
            done
        fi

        # 3. Ensure worker running
        if ! is_worker_running; then
            log "[-] Worker detected as stopped"
            start_worker
        fi

        sleep "$INTERVAL"
    done
}

main "$@"