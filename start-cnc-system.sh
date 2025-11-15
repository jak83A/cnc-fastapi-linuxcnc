

#!/bin/bash
# =============================================================================
# CNC Control System - Working Startup Script
# =============================================================================
# Fixed version - addresses DISPLAY and nohup issues
# =============================================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
MESA_IP="10.10.10.11"
LINUXCNC_DIR="$HOME/linuxcnc"
PROJECT_DIR="$HOME/PycharmProjects"
CONFIG_DIR="$PROJECT_DIR/linuxcnc_configs/zero3-mesa7i92"
CONFIG_FILE="$CONFIG_DIR/zero3-mesa7i92.ini"
LOG_FILE="/tmp/linuxcnc_startup.log"

# Print header
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   CNC Control System - Complete Startup       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Check Mesa connection
echo -e "${YELLOW}[1/5]${NC} Checking Mesa 7i92 connection..."
if ping -c 1 -W 1 "$MESA_IP" &> /dev/null; then
    echo -e "${GREEN}✓${NC} Mesa 7i92 card responding at $MESA_IP"
else
    echo -e "${RED}✗${NC} Cannot reach Mesa 7i92 at $MESA_IP"
    exit 1
fi
echo ""

# Load LinuxCNC RIP environment
echo -e "${YELLOW}[2/5]${NC} Loading LinuxCNC environment..."
cd "$LINUXCNC_DIR"
source ./scripts/rip-environment

if command -v linuxcnc &> /dev/null; then
    echo -e "${GREEN}✓${NC} LinuxCNC environment loaded"
else
    echo -e "${RED}✗${NC} LinuxCNC not available after sourcing RIP"
    exit 1
fi
echo ""

# Stop existing LinuxCNC
echo -e "${YELLOW}[3/5]${NC} Checking for existing LinuxCNC processes..."
if pgrep -f "linuxcnc.*\.ini" > /dev/null; then
    echo "     Stopping existing LinuxCNC..."
    pkill -f "linuxcnc.*\.ini" 2>/dev/null || true
    sleep 2
fi
echo -e "${GREEN}✓${NC} No conflicting processes"
echo ""

# Check config
echo -e "${YELLOW}[4/5]${NC} Verifying configuration..."
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}✗${NC} Config file not found: $CONFIG_FILE"
    exit 1
fi
echo -e "${GREEN}✓${NC} Configuration file present"
echo ""

# Start LinuxCNC
echo -e "${YELLOW}[5/5]${NC} Starting LinuxCNC in headless mode..."

# Clear log
> "$LOG_FILE"

# CRITICAL FIX: Start Xvfb if not running, or use existing display
if command -v Xvfb &> /dev/null; then
    if ! pgrep -x "Xvfb" > /dev/null; then
        echo "     Starting Xvfb virtual display..."
        Xvfb :1 -screen 0 1024x768x24 &> /dev/null &
        sleep 2
    fi
    export DISPLAY=:1
    echo "     Using virtual display: DISPLAY=$DISPLAY"
else
    # Fallback to :0 if Xvfb not available
    export DISPLAY=:0
    echo "     Using display: DISPLAY=$DISPLAY"
fi

# Change to config directory
cd "$CONFIG_DIR"

# Start LinuxCNC in background with nohup
echo "     Starting LinuxCNC process..."
nohup linuxcnc "$CONFIG_FILE" > "$LOG_FILE" 2>&1 &
LINUXCNC_PID=$!

echo "     Waiting for LinuxCNC to initialize (PID: $LINUXCNC_PID)..."

# Wait for successful startup
MAX_WAIT=30
SUCCESS=false

for i in $(seq 1 $MAX_WAIT); do
    # Check if process is still alive
    if ! kill -0 $LINUXCNC_PID 2>/dev/null; then
        echo ""
        echo -e "${RED}✗${NC} LinuxCNC process died"
        echo ""
        echo "Error log:"
        cat "$LOG_FILE" | tail -20 | sed 's/^/  /'
        exit 1
    fi
    
    # Check for successful startup indicators
    if grep -q "task: main loop" "$LOG_FILE" 2>/dev/null; then
        SUCCESS=true
        break
    fi
    
    # Check for task module
    if pgrep -f "milltask" > /dev/null 2>&1; then
        SUCCESS=true
        break
    fi
    
    # Check for errors
    if grep -qi "error.*loading.*hal\|fatal\|cannot open" "$LOG_FILE" 2>/dev/null; then
        echo ""
        echo -e "${RED}✗${NC} LinuxCNC encountered errors during startup"
        echo ""
        echo "Error log:"
        grep -i "error\|fatal" "$LOG_FILE" | tail -10 | sed 's/^/  /'
        echo ""
        echo "Full log: cat $LOG_FILE"
        exit 1
    fi
    
    sleep 1
    echo -n "."
done

echo ""

if [ "$SUCCESS" = true ]; then
    echo -e "${GREEN}✓${NC} LinuxCNC started successfully (PID: $LINUXCNC_PID)"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  LinuxCNC System Ready${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    echo ""
    echo "Configuration: $CONFIG_FILE"
    echo "Log file:      $LOG_FILE"
    echo ""
    echo "Monitor logs: tail -f $LOG_FILE"
    echo "Stop system:  pkill -f 'linuxcnc.*\\.ini'"
    echo ""
else
    echo -e "${YELLOW}⚠${NC}  Startup verification timeout"
    echo "Process is running (PID: $LINUXCNC_PID) but couldn't verify startup"
    echo "Check logs: tail -f $LOG_FILE"
fi

exit 0
