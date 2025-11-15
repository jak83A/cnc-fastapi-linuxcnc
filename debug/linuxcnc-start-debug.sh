#!/bin/bash
# =============================================================================
# LinuxCNC Debug Launcher
# =============================================================================
# This script runs LinuxCNC interactively so we can see the actual error
# =============================================================================

echo "========================================="
echo "LinuxCNC Debug Launcher"
echo "========================================="
echo ""

# Source RIP environment
echo "[1] Sourcing LinuxCNC RIP environment..."
cd ~/linuxcnc
source ./scripts/rip-environment
echo "✓ RIP environment loaded"
echo ""

# Start Xvfb
echo "[2] Starting Xvfb virtual display..."
if pgrep -x "Xvfb" > /dev/null; then
    echo "✓ Xvfb already running"
else
    Xvfb :1 -screen 0 1024x768x24 &
    XVFB_PID=$!
    sleep 2
    echo "✓ Xvfb started (PID: $XVFB_PID)"
fi
export DISPLAY=:1
echo "✓ DISPLAY=$DISPLAY"
echo ""

# Show configuration
CONFIG_FILE="$HOME/PycharmProjects/linuxcnc_configs/zero3-mesa7i92/zero3-mesa7i92.ini"
echo "[3] Configuration file:"
echo "    $CONFIG_FILE"
echo ""

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found!"
    exit 1
fi

echo "[4] Checking HAL file reference in INI..."
HAL_FILE=$(grep "^HALFILE" "$CONFIG_FILE" | head -1 | cut -d= -f2 | tr -d ' ')
echo "    HAL file: $HAL_FILE"
echo ""

# Change to config directory
cd "$(dirname "$CONFIG_FILE")"
echo "[5] Changed to directory: $(pwd)"
echo ""

# List files
echo "[6] Files in config directory:"
ls -la
echo ""

echo "[7] Attempting to start LinuxCNC..."
echo "    Command: linuxcnc -v \"$CONFIG_FILE\""
echo ""
echo "========================================="
echo "LinuxCNC OUTPUT (verbose mode):"
echo "========================================="
echo ""

# Run LinuxCNC in verbose mode (foreground, not background)
linuxcnc -v "$CONFIG_FILE"

echo ""
echo "========================================="
echo "LinuxCNC exited"
echo "========================================="
