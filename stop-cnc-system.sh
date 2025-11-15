#!/bin/bash
# =============================================================================
# CNC Control System - Stop Script
# =============================================================================
# Safely stops LinuxCNC and FastAPI processes
# =============================================================================

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
FASTAPI_PID_FILE="/tmp/fastapi.pid"
LINUXCNC_LOG="/tmp/linuxcnc_startup.log"
FASTAPI_LOG="/tmp/fastapi.log"

# ============================================================================
# FUNCTIONS
# ============================================================================

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   CNC Control System - Shutdown               ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo ""
}

stop_linuxcnc() {
    echo -e "${YELLOW}[1/3]${NC} Stopping LinuxCNC..."

    if pgrep -f "linuxcnc.*\.ini" > /dev/null; then
        pkill -f "linuxcnc.*\.ini"

        # Wait for processes to stop
        for i in {1..10}; do
            if ! pgrep -f "linuxcnc.*\.ini" > /dev/null; then
                break
            fi
            sleep 0.5
        done

        # Force kill if still running
        if pgrep -f "linuxcnc.*\.ini" > /dev/null; then
            echo "     Force stopping LinuxCNC..."
            pkill -9 -f "linuxcnc.*\.ini"
            sleep 1
        fi

        echo -e "${GREEN}✓${NC} LinuxCNC stopped"
    else
        echo -e "${YELLOW}⚠${NC}  LinuxCNC not running"
    fi
    echo ""
}

stop_fastapi() {
    echo -e "${YELLOW}[2/3]${NC} Stopping FastAPI..."

    if [ -f "$FASTAPI_PID_FILE" ]; then
        FASTAPI_PID=$(cat "$FASTAPI_PID_FILE")

        if kill -0 "$FASTAPI_PID" 2>/dev/null; then
            kill "$FASTAPI_PID"

            # Wait for process to stop
            for i in {1..10}; do
                if ! kill -0 "$FASTAPI_PID" 2>/dev/null; then
                    break
                fi
                sleep 0.5
            done

            # Force kill if still running
            if kill -0 "$FASTAPI_PID" 2>/dev/null; then
                echo "     Force stopping FastAPI..."
                kill -9 "$FASTAPI_PID" 2>/dev/null
                sleep 1
            fi

            echo -e "${GREEN}✓${NC} FastAPI stopped (PID: $FASTAPI_PID)"
        else
            echo -e "${YELLOW}⚠${NC}  FastAPI process not found (stale PID file)"
        fi

        rm -f "$FASTAPI_PID_FILE"
    else
        # Check if uvicorn is running anyway
        if pgrep -f "uvicorn.*app.main:app" > /dev/null; then
            echo "     Found running uvicorn process..."
            pkill -f "uvicorn.*app.main:app"
            sleep 1
            echo -e "${GREEN}✓${NC} FastAPI stopped"
        else
            echo -e "${YELLOW}⚠${NC}  FastAPI not running"
        fi
    fi
    echo ""
}

stop_xvfb() {
    echo -e "${YELLOW}[3/3]${NC} Cleaning up virtual display..."

    if pgrep -x "Xvfb" > /dev/null; then
        # Only stop Xvfb if it was started for LinuxCNC (display :1)
        if pgrep -x "Xvfb" -a | grep -q ":1"; then
            pkill -x Xvfb
            sleep 1
            echo -e "${GREEN}✓${NC} Xvfb stopped"
        else
            echo -e "${YELLOW}⚠${NC}  Xvfb running on other display (not stopped)"
        fi
    else
        echo -e "${YELLOW}⚠${NC}  Xvfb not running"
    fi
    echo ""
}

verify_stopped() {
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Shutdown Complete${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    echo ""

    # Check if anything is still running
    STILL_RUNNING=false

    if pgrep -f "linuxcnc.*\.ini" > /dev/null; then
        echo -e "${RED}⚠${NC}  WARNING: LinuxCNC processes still running"
        STILL_RUNNING=true
    fi

    if pgrep -f "uvicorn.*app.main:app" > /dev/null; then
        echo -e "${RED}⚠${NC}  WARNING: FastAPI processes still running"
        STILL_RUNNING=true
    fi

    if [ "$STILL_RUNNING" = false ]; then
        echo "All CNC system processes stopped successfully."
        echo ""
        echo "Log files preserved:"
        [ -f "$LINUXCNC_LOG" ] && echo "  LinuxCNC: $LINUXCNC_LOG"
        [ -f "$FASTAPI_LOG" ] && echo "  FastAPI:  $FASTAPI_LOG"
    fi
    echo ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

print_header
stop_linuxcnc
stop_fastapi
stop_xvfb
verify_stopped

exit 0
