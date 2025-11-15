#!/bin/bash
# =============================================================================
# CNC Control System - Complete Startup Script (LinuxCNC + FastAPI)
# =============================================================================
# Starts LinuxCNC in headless mode, then launches FastAPI application
# =============================================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================================
# CONFIGURATION - Update these paths for your system
# ============================================================================

# LinuxCNC Configuration
MESA_IP="10.10.10.11"
LINUXCNC_DIR="$HOME/linuxcnc"
PROJECT_DIR="$HOME/PycharmProjects"
CONFIG_DIR="$LINUXCNC_DIR/configs/zero3-mesa7i92"
CONFIG_FILE="$CONFIG_DIR/zero3-mesa7i92.ini"
LINUXCNC_LOG="/tmp/linuxcnc_startup.log"

# FastAPI Configuration
FASTAPI_PROJECT_DIR="$PROJECT_DIR/cnc-fastapi-linuxcnc"         # FastAPI project directory
VENV_PATH="$FASTAPI_PROJECT_DIR/venv"                           # Virtual environment path
FASTAPI_APP="app.main:app"                                       # Format: module.file:app_instance
FASTAPI_HOST="0.0.0.0"                                          # 0.0.0.0 = accessible from network
FASTAPI_PORT=8000
FASTAPI_LOG="/tmp/fastapi.log"
FASTAPI_PID_FILE="/tmp/fastapi.pid"

# ============================================================================
# FUNCTIONS
# ============================================================================

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   CNC Control System - Complete Startup       ║${NC}"
    echo -e "${BLUE}║   LinuxCNC + FastAPI REST API                  ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_mesa() {
    echo -e "${YELLOW}[1/6]${NC} Checking Mesa 7i92 connection..."
    if ping -c 1 -W 1 "$MESA_IP" &> /dev/null; then
        echo -e "${GREEN}✓${NC} Mesa 7i92 card responding at $MESA_IP"
    else
        echo -e "${RED}✗${NC} Cannot reach Mesa 7i92 at $MESA_IP"
        exit 1
    fi
    echo ""
}

load_linuxcnc_env() {
    echo -e "${YELLOW}[2/6]${NC} Loading LinuxCNC environment..."
    cd "$LINUXCNC_DIR"
    source ./scripts/rip-environment

    if command -v linuxcnc &> /dev/null; then
        echo -e "${GREEN}✓${NC} LinuxCNC environment loaded"
    else
        echo -e "${RED}✗${NC} LinuxCNC not available after sourcing RIP"
        exit 1
    fi
    echo ""
}

stop_existing_processes() {
    echo -e "${YELLOW}[3/6]${NC} Checking for existing processes..."
    
    # Stop existing LinuxCNC
    if pgrep -f "linuxcnc.*\.ini" > /dev/null; then
        echo "     Stopping existing LinuxCNC..."
        pkill -f "linuxcnc.*\.ini" 2>/dev/null || true
        sleep 2
    fi
    
    # Stop existing FastAPI
    if [ -f "$FASTAPI_PID_FILE" ]; then
        OLD_PID=$(cat "$FASTAPI_PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            echo "     Stopping existing FastAPI (PID: $OLD_PID)..."
            kill "$OLD_PID" 2>/dev/null || true
            sleep 1
        fi
        rm -f "$FASTAPI_PID_FILE"
    fi
    
    echo -e "${GREEN}✓${NC} No conflicting processes"
    echo ""
}

verify_config() {
    echo -e "${YELLOW}[4/6]${NC} Verifying configuration..."
    
    # Check LinuxCNC config
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}✗${NC} LinuxCNC config not found: $CONFIG_FILE"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} LinuxCNC configuration file present"
    
    # Check FastAPI project
    if [ ! -d "$FASTAPI_PROJECT_DIR" ]; then
        echo -e "${YELLOW}⚠${NC}  FastAPI project directory not found: $FASTAPI_PROJECT_DIR"
        echo "     FastAPI will not be started. Only LinuxCNC will run."
        SKIP_FASTAPI=true
    else
        echo -e "${GREEN}✓${NC} FastAPI project directory found"
        SKIP_FASTAPI=false
    fi
    
    # Check virtual environment
    if [ "$SKIP_FASTAPI" = false ] && [ ! -d "$VENV_PATH" ]; then
        echo -e "${YELLOW}⚠${NC}  Virtual environment not found: $VENV_PATH"
        echo "     Run: python3 -m venv $VENV_PATH"
        SKIP_FASTAPI=true
    elif [ "$SKIP_FASTAPI" = false ]; then
        echo -e "${GREEN}✓${NC} Virtual environment found"
    fi
    
    echo ""
}

start_linuxcnc() {
    echo -e "${YELLOW}[5/6]${NC} Starting LinuxCNC in headless mode..."
    
    # Clear log
    > "$LINUXCNC_LOG"
    
    # Setup display
    if command -v Xvfb &> /dev/null; then
        if ! pgrep -x "Xvfb" > /dev/null; then
            echo "     Starting Xvfb virtual display..."
            Xvfb :1 -screen 0 1024x768x24 &> /dev/null &
            sleep 2
        fi
        export DISPLAY=:1
        echo "     Using virtual display: DISPLAY=$DISPLAY"
    else
        export DISPLAY=:0
        echo "     Using display: DISPLAY=$DISPLAY"
    fi
    
    # Change to config directory
    cd "$CONFIG_DIR"

    # Verify linuxcnc is available
    echo "     Running pre-flight checks..."
    if ! command -v linuxcnc &> /dev/null; then
        echo -e "${RED}✗${NC} linuxcnc command not found in PATH"
        echo "     PATH: $PATH"
        exit 1
    fi

    echo "     Config file: $CONFIG_FILE"
    echo "     Working directory: $(pwd)"

    # Start LinuxCNC
    echo "     Starting LinuxCNC process..."
    nohup linuxcnc "$CONFIG_FILE" > "$LINUXCNC_LOG" 2>&1 &
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
            cat "$LINUXCNC_LOG" | tail -20 | sed 's/^/  /'
            exit 1
        fi
        
        # Check for successful startup
        if grep -q "task: main loop" "$LINUXCNC_LOG" 2>/dev/null; then
            SUCCESS=true
            break
        fi
        
        if pgrep -f "milltask" > /dev/null 2>&1; then
            SUCCESS=true
            break
        fi
        
        # Check for errors
        if grep -qi "error.*loading.*hal\|fatal\|cannot open" "$LINUXCNC_LOG" 2>/dev/null; then
            echo ""
            echo -e "${RED}✗${NC} LinuxCNC encountered errors during startup"
            echo ""
            echo "Error log:"
            grep -i "error\|fatal" "$LINUXCNC_LOG" | tail -10 | sed 's/^/  /'
            echo ""
            echo "Full log: cat $LINUXCNC_LOG"
            exit 1
        fi
        
        sleep 1
        echo -n "."
    done
    
    echo ""
    
    if [ "$SUCCESS" = true ]; then
        echo -e "${GREEN}✓${NC} LinuxCNC started successfully (PID: $LINUXCNC_PID)"
    else
        echo -e "${YELLOW}⚠${NC}  Startup verification timeout"
        echo "     Process running (PID: $LINUXCNC_PID) but couldn't verify startup"
        echo "     Check logs: tail -f $LINUXCNC_LOG"
    fi
    echo ""
}

start_fastapi() {
    if [ "$SKIP_FASTAPI" = true ]; then
        echo -e "${YELLOW}[6/6]${NC} Skipping FastAPI (not configured)"
        echo ""
        return
    fi

    echo -e "${YELLOW}[6/6]${NC} Starting FastAPI application..."

    cd "$FASTAPI_PROJECT_DIR"

    # Activate virtual environment
    echo "     Activating virtual environment..."
    source "$VENV_PATH/bin/activate"

    # Clear log
    > "$FASTAPI_LOG"

    # Set LinuxCNC environment variables for FastAPI
    # These are critical for the linuxcnc Python module to connect via NML
    echo "     Setting LinuxCNC Python path: $LINUXCNC_DIR/lib/python"
    export PYTHONPATH="$LINUXCNC_DIR/lib/python:$PYTHONPATH"

    echo "     Setting LinuxCNC environment:"
    export INI_FILE_NAME="$CONFIG_FILE"
    export EMC2_HOME="$LINUXCNC_DIR"
    export NMLFILE="$LINUXCNC_DIR/configs/common/linuxcnc.nml"
    export LD_LIBRARY_PATH="$LINUXCNC_DIR/lib:$LD_LIBRARY_PATH"

    echo "       INI_FILE_NAME=$INI_FILE_NAME"
    echo "       EMC2_HOME=$EMC2_HOME"
    echo "       NMLFILE=$NMLFILE"
    echo "       LD_LIBRARY_PATH includes: $LINUXCNC_DIR/lib"

    # Start FastAPI with uvicorn
    echo "     Starting uvicorn server..."
    nohup uvicorn "$FASTAPI_APP" \
        --host "$FASTAPI_HOST" \
        --port "$FASTAPI_PORT" \
        --log-level info \
        > "$FASTAPI_LOG" 2>&1 &
    
    FASTAPI_PID=$!
    echo "$FASTAPI_PID" > "$FASTAPI_PID_FILE"
    
    # Wait briefly and check if it started
    sleep 3
    
    if kill -0 "$FASTAPI_PID" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} FastAPI started successfully (PID: $FASTAPI_PID)"
        echo ""
        echo -e "${CYAN}     API URL:  http://localhost:$FASTAPI_PORT${NC}"
        echo -e "${CYAN}     API Docs: http://localhost:$FASTAPI_PORT/docs${NC}"
        echo -e "${CYAN}     Redoc:    http://localhost:$FASTAPI_PORT/redoc${NC}"
    else
        echo -e "${RED}✗${NC} FastAPI failed to start"
        echo ""
        echo "Error log:"
        cat "$FASTAPI_LOG" | tail -20 | sed 's/^/  /'
        # Don't exit - LinuxCNC is still running
    fi
    echo ""
}

print_summary() {
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  System Ready${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    echo ""
    echo "LinuxCNC:"
    echo "  Configuration: $CONFIG_FILE"
    echo "  Log file:      $LINUXCNC_LOG"
    echo "  Monitor:       tail -f $LINUXCNC_LOG"
    echo ""
    
    if [ "$SKIP_FASTAPI" = false ]; then
        echo "FastAPI:"
        echo "  API URL:       http://localhost:$FASTAPI_PORT"
        echo "  Documentation: http://localhost:$FASTAPI_PORT/docs"
        echo "  Log file:      $FASTAPI_LOG"
        echo "  Monitor:       tail -f $FASTAPI_LOG"
        echo ""
    fi
    
    echo "Commands:"
    echo "  Stop LinuxCNC: pkill -f 'linuxcnc.*\\.ini'"
    if [ "$SKIP_FASTAPI" = false ] && [ -f "$FASTAPI_PID_FILE" ]; then
        echo "  Stop FastAPI:  kill \$(cat $FASTAPI_PID_FILE)"
    fi
    echo "  Stop both:     pkill -f 'linuxcnc.*\\.ini'; kill \$(cat $FASTAPI_PID_FILE 2>/dev/null)"
    echo ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

print_header
check_mesa
load_linuxcnc_env
stop_existing_processes
verify_config
start_linuxcnc
start_fastapi
print_summary

exit 0
