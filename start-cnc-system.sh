#!/bin/bash
# Complete startup script for LinuxCNC (headless) + FastAPI
# Mesa 7i92 + Zero-3 CNC configuration

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   CNC Control System - Complete Startup       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# ===== STEP 1: Check Mesa Card =====
echo -e "${YELLOW}[1/5]${NC} Checking Mesa 7i92 connection..."
if ping -c 1 -W 1 10.10.10.11 &> /dev/null; then
    echo -e "${GREEN}✓${NC} Mesa 7i92 card responding at 10.10.10.11"
else
    echo -e "${RED}✗${NC} Cannot reach Mesa 7i92 at 10.10.10.11"
    echo "      Check network cable and IP configuration"
    exit 1
fi

# ===== STEP 2: Source LinuxCNC Environment =====
echo ""
echo -e "${YELLOW}[2/5]${NC} Loading LinuxCNC environment..."
cd ~/linuxcnc
source ./scripts/rip-environment

if ! command -v linuxcnc &> /dev/null; then
    echo -e "${RED}✗${NC} LinuxCNC not found after sourcing RIP"
    exit 1
fi
echo -e "${GREEN}✓${NC} LinuxCNC environment loaded (version $(linuxcnc --version 2>/dev/null | head -1 || echo '2.9.7'))"

# ===== STEP 3: Start LinuxCNC Headless =====
echo ""
echo -e "${YELLOW}[3/5]${NC} Starting LinuxCNC in headless mode..."

# Unset DISPLAY for headless operation
unset DISPLAY

CONFIG_PATH="$HOME/PycharmProjects/linuxcnc_configs/zero3-mesa7i92/zero3-mesa7i92.ini"

if [ ! -f "$CONFIG_PATH" ]; then
    echo -e "${RED}✗${NC} Config file not found: $CONFIG_PATH"
    exit 1
fi

# Kill any existing LinuxCNC processes
if pgrep -f "linuxcnc" > /dev/null; then
    echo "      Stopping existing LinuxCNC processes..."
    killall -9 linuxcnc milltask io halui linuxcncsvr 2>/dev/null || true
    sleep 2
fi

# Start LinuxCNC in background
linuxcnc "$CONFIG_PATH" > /tmp/linuxcnc_startup.log 2>&1 &
LINUXCNC_PID=$!

# Wait for LinuxCNC to initialize
echo "      Waiting for LinuxCNC to initialize..."
sleep 5

# Check if LinuxCNC is running
if ! pgrep -f "milltask" > /dev/null; then
    echo -e "${RED}✗${NC} LinuxCNC failed to start"
    echo ""
    echo "Last 30 lines of log:"
    tail -30 /tmp/linuxcnc_startup.log
    echo ""
    echo "Check full logs:"
    echo "  cat /tmp/linuxcnc_startup.log"
    echo "  cat ~/linuxcnc_debug.txt"
    exit 1
fi

echo -e "${GREEN}✓${NC} LinuxCNC started successfully"
ps aux | grep -E "milltask|iocontrol" | grep -v grep | awk '{print "      PID " $2 ": " $11}'

# ===== STEP 4: Verify LinuxCNC API Connection =====
echo ""
echo -e "${YELLOW}[4/5]${NC} Verifying LinuxCNC Python API connection..."

# Test Python API connection
python3 << 'PYTHON_TEST'
import sys
sys.path.append('/usr/lib/python3/dist-packages')
try:
    import linuxcnc
    s = linuxcnc.stat()
    s.poll()
    print("\033[0;32m✓\033[0m LinuxCNC API accessible")
    print(f"      Task state: {s.task_state} (1=ESTOP, 2=ESTOP_RESET, 3=OFF, 4=ON)")
    print(f"      Joints: {getattr(s, 'joints', 'N/A')}")
    sys.exit(0)
except Exception as e:
    print(f"\033[0;31m✗\033[0m API connection failed: {e}")
    sys.exit(1)
PYTHON_TEST

if [ $? -ne 0 ]; then
    echo -e "${RED}✗${NC} Python API test failed"
    exit 1
fi

# ===== STEP 5: Start FastAPI =====
echo ""
echo -e "${YELLOW}[5/5]${NC} Starting FastAPI server..."

# Check for virtual environment
VENV_PATH="$HOME/PycharmProjects/venv"
if [ ! -f "$VENV_PATH/bin/activate" ]; then
    echo -e "${RED}✗${NC} Virtual environment not found at $VENV_PATH"
    echo "      Create it with: python3 -m venv $VENV_PATH"
    exit 1
fi

# Activate venv
source "$VENV_PATH/bin/activate"

# Check if FastAPI is installed
if ! python -c "import fastapi" 2>/dev/null; then
    echo -e "${YELLOW}⚠${NC}  FastAPI not installed. Installing dependencies..."
    pip install --break-system-packages fastapi uvicorn pydantic pydantic-settings
fi

echo -e "${GREEN}✓${NC} Virtual environment activated"

# Set environment variables for API
export LINUXCNC_CONFIG_PATH="$CONFIG_PATH"
export LINUXCNC_AUTO_START=false

# Start FastAPI
echo ""
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ System Ready!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo ""
echo "LinuxCNC:     Running (PID: $LINUXCNC_PID)"
echo "Mesa 7i92:    Connected (192.168.192.210)"
echo ""
echo "Starting FastAPI server..."
echo "API will be available at: http://0.0.0.0:8000"
echo "API docs:                 http://0.0.0.0:8000/docs"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop the API server${NC}"
echo ""

# Change to your API project directory
cd ~/PycharmProjects  # Adjust this to your actual API project path

# Start uvicorn
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
