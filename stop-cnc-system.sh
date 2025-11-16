#!/bin/bash
# =============================================================================
# CNC Control System - Shutdown Script
# =============================================================================

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

FASTAPI_PID_FILE="/tmp/fastapi.pid"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   CNC Control System - Shutdown               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Stop LinuxCNC
echo -e "${YELLOW}[1/3]${NC} Stopping LinuxCNC..."
if pgrep -f "linuxcnc.*\.ini" > /dev/null 2>&1; then
    pkill -f "linuxcnc.*\.ini" 2>/dev/null
    sleep 2
    # Force kill if still running
    if pgrep -f "linuxcnc.*\.ini" > /dev/null 2>&1; then
        pkill -9 -f "linuxcnc.*\.ini" 2>/dev/null
    fi
    echo -e "${GREEN}✓${NC} LinuxCNC stopped"
else
    echo -e "${YELLOW}⚠${NC}  LinuxCNC not running"
fi

# Clean up expect process (if using expect-based startup)
if [ -f "/tmp/linuxcnc_expect.pid" ]; then
    EXPECT_PID=$(cat "/tmp/linuxcnc_expect.pid" 2>/dev/null)
    if [ -n "$EXPECT_PID" ] && kill -0 "$EXPECT_PID" 2>/dev/null; then
        echo "     Stopping expect process (PID: $EXPECT_PID)..."
        kill "$EXPECT_PID" 2>/dev/null
    fi
    rm -f "/tmp/linuxcnc_expect.pid"
fi

# Clean up FIFO feeder process (legacy, if still present)
if [ -f "/tmp/linuxcnc_feeder.pid" ]; then
    FEEDER_PID=$(cat "/tmp/linuxcnc_feeder.pid" 2>/dev/null)
    if [ -n "$FEEDER_PID" ] && kill -0 "$FEEDER_PID" 2>/dev/null; then
        kill "$FEEDER_PID" 2>/dev/null
    fi
    rm -f "/tmp/linuxcnc_feeder.pid"
fi
if [ -f "/tmp/linuxcnc_fifo.path" ]; then
    FIFO_PATH=$(cat "/tmp/linuxcnc_fifo.path" 2>/dev/null)
    rm -f "$FIFO_PATH" "/tmp/linuxcnc_fifo.path"
fi

# Stop FastAPI
echo -e "${YELLOW}[2/3]${NC} Stopping FastAPI..."
if [ -f "$FASTAPI_PID_FILE" ]; then
    FASTAPI_PID=$(cat "$FASTAPI_PID_FILE" 2>/dev/null)
    if [ -n "$FASTAPI_PID" ] && kill -0 "$FASTAPI_PID" 2>/dev/null; then
        kill "$FASTAPI_PID" 2>/dev/null
        sleep 1
        echo -e "${GREEN}✓${NC} FastAPI stopped (PID: $FASTAPI_PID)"
    else
        echo -e "${YELLOW}⚠${NC}  FastAPI PID file exists but process not running"
    fi
    rm -f "$FASTAPI_PID_FILE"
else
    # Try to find uvicorn process
    if pgrep -f "uvicorn.*app.main:app" > /dev/null 2>&1; then
        pkill -f "uvicorn.*app.main:app" 2>/dev/null
        echo -e "${GREEN}✓${NC} FastAPI stopped"
    else
        echo -e "${YELLOW}⚠${NC}  FastAPI not running"
    fi
fi

# Stop Xvfb
echo -e "${YELLOW}[3/3]${NC} Cleaning up virtual display..."
if pgrep -x "Xvfb" > /dev/null 2>&1; then
    pkill -x "Xvfb" 2>/dev/null
    echo -e "${GREEN}✓${NC} Xvfb stopped"
else
    echo -e "${YELLOW}⚠${NC}  Xvfb not running"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Shutdown Complete${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""
echo "All CNC system processes stopped successfully."
echo ""
echo "Log files preserved:"
echo "  LinuxCNC: /tmp/linuxcnc_startup.log"
echo "  FastAPI:  /tmp/fastapi.log"
echo ""
