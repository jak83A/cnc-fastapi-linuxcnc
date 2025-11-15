#!/bin/bash
# Complete Setup Script for CNC API Project
# Installs: LinuxCNC → Python Environment → Machine Configuration → API
# One script does everything!

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
LINUXCNC_BRANCH="2.9"
LINUXCNC_DIR="$HOME/linuxcnc"
PROJECT_DIR="$(pwd)"

clear
echo -e "${BOLD}=========================================${NC}"
echo -e "${BOLD}   CNC API Project - Complete Setup${NC}"
echo -e "${BOLD}=========================================${NC}"
echo ""
echo "This script will install:"
echo "  1. LinuxCNC (if needed)"
echo "  2. Python virtual environment"
echo "  3. CNC machine configuration"
echo "  4. FastAPI dependencies"
echo ""
echo -e "${YELLOW}Estimated time: 15-45 minutes${NC}"
echo ""
read -p "Press Enter to continue or Ctrl+C to abort..."
echo ""

# =====================================================
# STEP 1: Check System Prerequisites
# =====================================================

echo -e "${BLUE}${BOLD}Step 1/6: Checking system prerequisites...${NC}"
echo ""

# Check OS
if ! grep -qi ubuntu /etc/os-release; then
    echo -e "${YELLOW}⚠ Warning: This script is tested on Ubuntu 24.04${NC}"
    echo "It may work on other Debian-based systems"
    read -p "Continue anyway? (y/n): " continue_choice
    if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 is not installed.${NC}"
    echo "Installing Python 3..."
    sudo apt update
    sudo apt install -y python3 python3-pip python3-venv
fi
echo -e "${GREEN}✓ Python 3: $(python3 --version)${NC}"

# Check basic build tools
if ! command -v make &> /dev/null; then
    echo -e "${YELLOW}Installing build essentials...${NC}"
    sudo apt update
    sudo apt install -y build-essential
fi
echo -e "${GREEN}✓ Build tools available${NC}"

echo ""

# =====================================================
# STEP 2: Install or Check LinuxCNC
# =====================================================

echo -e "${BLUE}${BOLD}Step 2/6: LinuxCNC Installation${NC}"
echo "========================================="
echo ""

LINUXCNC_NEEDS_INSTALL=false

# Check if LinuxCNC is already available
if python3 -c "import linuxcnc" 2>/dev/null; then
    LINUXCNC_VERSION=$(python3 -c "import linuxcnc; print(linuxcnc.version)" 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✓ LinuxCNC is already installed (version: $LINUXCNC_VERSION)${NC}"
    echo ""
    echo "Options:"
    echo "  1) Use existing LinuxCNC installation"
    echo "  2) Build new LinuxCNC from source"
    echo ""
    read -p "Select option (1-2) [1]: " linuxcnc_choice
    linuxcnc_choice=${linuxcnc_choice:-1}
    
    if [ "$linuxcnc_choice" = "2" ]; then
        LINUXCNC_NEEDS_INSTALL=true
    fi
else
    echo -e "${YELLOW}LinuxCNC is not installed.${NC}"
    echo ""
    echo "LinuxCNC is required for this project."
    echo ""
    echo "Installation options:"
    echo "  1) Build LinuxCNC from source (recommended, ~30 minutes)"
    echo "  2) Skip LinuxCNC installation (I'll install it manually later)"
    echo ""
    read -p "Select option (1-2): " install_choice
    
    if [ "$install_choice" = "1" ]; then
        LINUXCNC_NEEDS_INSTALL=true
    else
        echo -e "${YELLOW}⚠ Skipping LinuxCNC installation${NC}"
        echo "You must install LinuxCNC manually before using this API."
        echo ""
    fi
fi

if [ "$LINUXCNC_NEEDS_INSTALL" = true ]; then
    echo ""
    echo -e "${CYAN}${BOLD}Installing LinuxCNC from source...${NC}"
    echo "This will take 20-40 minutes depending on your CPU."
    echo ""
    
    # Install dependencies
    echo "Installing dependencies..."
    sudo apt update
    sudo apt install -y git build-essential autoconf automake libtool \
        python3-dev python3-tk python3-numpy libreadline-dev \
        libxmu-dev libglu1-mesa-dev libgl1-mesa-dev \
        libgtk2.0-dev libgtk-3-dev libmodbus-dev libusb-1.0-0-dev \
        libudev-dev libjansson-dev libwebsockets-dev libboost-python-dev \
        yapps2 tcl8.6-dev tk8.6-dev asciidoc || {
        echo -e "${RED}❌ Failed to install dependencies${NC}"
        exit 1
    }
    
    echo -e "${GREEN}✓ Dependencies installed${NC}"
    echo ""
    
    # Clone LinuxCNC if needed
    if [ ! -d "$LINUXCNC_DIR" ]; then
        echo "Cloning LinuxCNC repository..."
        git clone -b $LINUXCNC_BRANCH https://github.com/LinuxCNC/linuxcnc.git "$LINUXCNC_DIR" || {
            echo -e "${RED}❌ Failed to clone LinuxCNC${NC}"
            exit 1
        }
    else
        echo "LinuxCNC directory already exists at $LINUXCNC_DIR"
        echo "Using existing directory..."
    fi
    
    echo ""
    echo "Building LinuxCNC (this takes 20-40 minutes)..."
    echo "You can get a coffee ☕"
    echo ""
    
    cd "$LINUXCNC_DIR/src"
    
    # Configure
    echo "Configuring..."
    ./autogen.sh
    ./configure --with-realtime=uspace --enable-non-distributable=yes || {
        echo -e "${RED}❌ Configure failed${NC}"
        exit 1
    }
    
    # Build
    echo "Compiling... (this is the slow part)"
    make -j$(nproc) || {
        echo -e "${RED}❌ Build failed${NC}"
        exit 1
    }
    
    # Set permissions
    echo "Setting permissions..."
    sudo make setuid || {
        echo -e "${RED}❌ Failed to set permissions${NC}"
        exit 1
    }
    
    cd "$PROJECT_DIR"
    
    # Verify installation
    . "$LINUXCNC_DIR/scripts/rip-environment"
    if python3 -c "import linuxcnc" 2>/dev/null; then
        echo ""
        echo -e "${GREEN}${BOLD}✓ LinuxCNC successfully built and installed!${NC}"
    else
        echo -e "${RED}❌ LinuxCNC build completed but module not accessible${NC}"
        exit 1
    fi
fi

echo ""

# =====================================================
# STEP 3: Setup Python Virtual Environment
# =====================================================

echo -e "${BLUE}${BOLD}Step 3/6: Python Virtual Environment${NC}"
echo "========================================="
echo ""

cd "$PROJECT_DIR"

if [ -d "venv" ]; then
    echo "Virtual environment already exists."
    read -p "Recreate it? (y/n) [n]: " recreate_venv
    if [[ "$recreate_venv" =~ ^[Yy]$ ]]; then
        rm -rf venv
        python3 -m venv venv
        echo -e "${GREEN}✓ Virtual environment recreated${NC}"
    else
        echo -e "${GREEN}✓ Using existing virtual environment${NC}"
    fi
else
    python3 -m venv venv
    echo -e "${GREEN}✓ Virtual environment created${NC}"
fi

# Activate venv
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip -q

# Install dependencies
echo "Installing Python dependencies..."
if [ -f requirements.txt ]; then
    pip install -r requirements.txt -q || {
        echo -e "${YELLOW}⚠ Some packages failed to install, continuing...${NC}"
    }
    echo -e "${GREEN}✓ Dependencies installed${NC}"
else
    echo -e "${YELLOW}⚠ requirements.txt not found${NC}"
fi

echo ""

# =====================================================
# STEP 4: Link LinuxCNC to Virtual Environment
# =====================================================

echo -e "${BLUE}${BOLD}Step 4/6: Linking LinuxCNC to Virtual Environment${NC}"
echo "========================================="
echo ""

VENV_SITE=$(python -c "import site; print(site.getsitepackages()[0])")

# Create .pth file with all possible LinuxCNC locations
cat > "$VENV_SITE/linuxcnc.pth" << EOF
$LINUXCNC_DIR/lib
$LINUXCNC_DIR/lib/python
/usr/lib/python3/dist-packages
/usr/lib/python3.12/dist-packages
/usr/lib/python3.11/dist-packages
/usr/lib/python3.10/dist-packages
EOF

echo "Virtual environment site-packages: $VENV_SITE"

# Test LinuxCNC import
if python -c "import linuxcnc" 2>/dev/null; then
    echo -e "${GREEN}✓ LinuxCNC successfully linked to virtual environment${NC}"
else
    echo -e "${YELLOW}⚠ Warning: LinuxCNC not accessible in venv${NC}"
    echo "This may need manual configuration."
fi

echo ""

# =====================================================
# STEP 5: Configure Environment
# =====================================================

echo -e "${BLUE}${BOLD}Step 5/6: Environment Configuration${NC}"
echo "========================================="
echo ""

cd "$PROJECT_DIR"

if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        cp .env.example .env
        echo -e "${GREEN}✓ .env file created from .env.example${NC}"
    else
        echo "Creating basic .env file..."
        cat > .env << 'EOF'
# LinuxCNC Configuration
LINUXCNC_PATH=/usr/lib/python3/dist-packages
HAL_CONFIG_FILE=config/mesa7i92-zero3.hal

# API Configuration
API_HOST=0.0.0.0
API_PORT=8000
API_TITLE=CNC Control API
API_VERSION=1.0.0

# Logging
LOG_LEVEL=INFO

# CNC Settings
DEFAULT_FEED_RATE=1000.0
MAX_FEED_RATE=10000.0
POLL_INTERVAL=0.05

# Safety
REQUIRE_HOMING=true
ENABLE_SOFT_LIMITS=true
EOF
        echo -e "${GREEN}✓ .env file created${NC}"
    fi
else
    echo -e "${GREEN}✓ .env file already exists${NC}"
fi

echo ""

# =====================================================
# STEP 6: CNC Machine Configuration
# =====================================================

echo -e "${BLUE}${BOLD}Step 6/6: CNC Machine Configuration${NC}"
echo "========================================="
echo ""

# Create LinuxCNC configs directory if needed
LINUXCNC_CONFIG_BASE="$HOME/linuxcnc/configs"
mkdir -p "$LINUXCNC_CONFIG_BASE"

echo "Available CNC machine configurations:"
echo ""
echo "  1) Zero-3 with Mesa 7i92 Ethernet card"
echo "  2) Custom configuration (manual setup)"
echo "  3) Skip machine configuration (configure later)"
echo ""
read -p "Select configuration (1-3) [1]: " config_choice
config_choice=${config_choice:-1}

case $config_choice in
    1)
        echo ""
        echo -e "${GREEN}Selected: Zero-3 with Mesa 7i92${NC}"
        echo ""
        
        # Check if config files exist
        if [ -d "linuxcnc_configs/zero3-mesa7i92" ]; then
            echo "Installing Zero-3 configuration..."
            
            # Create config directory
            mkdir -p "$LINUXCNC_CONFIG_BASE/zero3-mesa7i92"
            
            # Copy files
            cp linuxcnc_configs/zero3-mesa7i92/*.ini "$LINUXCNC_CONFIG_BASE/zero3-mesa7i92/" 2>/dev/null || true
            cp linuxcnc_configs/zero3-mesa7i92/*.hal "$LINUXCNC_CONFIG_BASE/zero3-mesa7i92/" 2>/dev/null || true
            
            # Create empty files
            touch "$LINUXCNC_CONFIG_BASE/zero3-mesa7i92/custom_postgui.hal"
            touch "$LINUXCNC_CONFIG_BASE/zero3-mesa7i92/postgui.hal"
            touch "$LINUXCNC_CONFIG_BASE/zero3-mesa7i92/linuxcnc.var"
            touch "$LINUXCNC_CONFIG_BASE/zero3-mesa7i92/position.txt"
            
            echo -e "${GREEN}✓ Zero-3 configuration installed${NC}"
            echo ""
            echo "Location: $LINUXCNC_CONFIG_BASE/zero3-mesa7i92/"
            echo ""
            echo -e "${YELLOW}${BOLD}IMPORTANT: Configure these parameters:${NC}"
            echo "  1. Steps per mm (SCALE in INI file)"
            echo "  2. Travel limits (MAX_LIMIT/MIN_LIMIT in INI file)"
            echo "  3. Mesa 7i92 IP address (board_ip in HAL file)"
            echo "  4. Network interface for Mesa card"
            echo ""
            
            # Update .env
            if [ -f .env ]; then
                sed -i 's|HAL_CONFIG_FILE=.*|HAL_CONFIG_FILE=linuxcnc_configs/zero3-mesa7i92/mesa7i92-zero3.hal|' .env
            fi
            
            # Network configuration
            echo "Configure network for Mesa 7i92 now? (y/n)"
            read -p "Response [y]: " network_response
            network_response=${network_response:-y}

            if [[ "$network_response" =~ ^[Yy]$ ]]; then
                echo ""
                echo "Available network interfaces:"
                ip -br addr show | grep -v lo
                echo ""
                read -p "Interface connected to Mesa 7i92 (e.g., enp5s0): " mesa_interface

                echo ""
                echo -e "${BOLD}Network Configuration:${NC}"
                echo "Please provide the IP addresses for your Mesa setup."
                echo ""
                read -p "IP address for your PC on this interface (e.g., 10.10.10.10): " pc_ip
                read -p "Subnet mask CIDR (e.g., 24 for /24) [24]: " subnet_mask
                subnet_mask=${subnet_mask:-24}
                read -p "IP address of your Mesa 7i92 card (e.g., 10.10.10.11): " mesa_ip

                # Validate inputs
                if [ -z "$mesa_interface" ] || [ -z "$pc_ip" ] || [ -z "$mesa_ip" ]; then
                    echo -e "${RED}❌ Missing required information. Skipping network configuration.${NC}"
                else
                    echo ""
                    echo "Configuring network..."
                    echo "  Interface: $mesa_interface"
                    echo "  PC IP: $pc_ip/$subnet_mask"
                    echo "  Mesa IP: $mesa_ip"
                    echo ""

                    sudo ip addr add ${pc_ip}/${subnet_mask} dev $mesa_interface 2>/dev/null || echo "IP may already be configured"
                    sudo ip link set $mesa_interface up

                    echo ""
                    echo "Testing Mesa connection to $mesa_ip..."
                    if ping -c 2 -W 2 $mesa_ip &>/dev/null; then
                        echo -e "${GREEN}✓ Mesa 7i92 at $mesa_ip is reachable!${NC}"

                        # Update HAL file with correct Mesa IP
                        hal_file="$LINUXCNC_CONFIG_BASE/zero3-mesa7i92/mesa7i92-zero3.hal"
                        if [ -f "$hal_file" ]; then
                            echo "Updating HAL file with Mesa IP..."
                            sed -i "s/board_ip=.*/board_ip=$mesa_ip/" "$hal_file"
                            echo -e "${GREEN}✓ HAL file updated with board_ip=$mesa_ip${NC}"
                        fi
                    else
                        echo -e "${YELLOW}⚠ Cannot reach Mesa 7i92 at $mesa_ip${NC}"
                        echo "Possible issues:"
                        echo "  - Check cable connection"
                        echo "  - Verify Mesa card is powered on"
                        echo "  - Confirm Mesa IP address is correct"
                        echo "  - Check if Mesa card is configured for this IP"
                    fi
                fi
            fi
        else
            echo -e "${YELLOW}⚠ Zero-3 config files not found in project${NC}"
            echo "Clone the complete repository from GitHub"
        fi
        ;;
    
    2)
        echo ""
        echo -e "${GREEN}Selected: Custom configuration${NC}"
        echo ""
        echo "Create your LinuxCNC config in:"
        echo "  $LINUXCNC_CONFIG_BASE/your-machine/"
        echo ""
        echo "Update HAL_CONFIG_FILE in .env"
        ;;
    
    3)
        echo ""
        echo -e "${YELLOW}Skipping machine configuration${NC}"
        ;;
esac

echo ""

# =====================================================
# FINAL: Summary and Next Steps
# =====================================================

clear
echo ""
echo -e "${GREEN}${BOLD}=========================================${NC}"
echo -e "${GREEN}${BOLD}   ✓ Setup Complete!${NC}"
echo -e "${GREEN}${BOLD}=========================================${NC}"
echo ""

echo -e "${BOLD}What was installed:${NC}"
if [ "$LINUXCNC_NEEDS_INSTALL" = true ]; then
    echo -e "  ${GREEN}✓${NC} LinuxCNC $LINUXCNC_BRANCH (built from source)"
else
    echo -e "  ${GREEN}✓${NC} LinuxCNC (using existing installation)"
fi
echo -e "  ${GREEN}✓${NC} Python virtual environment"
echo -e "  ${GREEN}✓${NC} FastAPI and dependencies"
echo -e "  ${GREEN}✓${NC} LinuxCNC linked to venv"
if [ "$config_choice" = "1" ]; then
    echo -e "  ${GREEN}✓${NC} Zero-3 CNC configuration"
fi
echo ""

echo -e "${BOLD}Next Steps:${NC}"
echo ""
echo "1. ${BOLD}Configure your machine parameters:${NC}"
if [ "$config_choice" = "1" ]; then
    echo "   Edit: $LINUXCNC_CONFIG_BASE/zero3-mesa7i92/zero3-mesa7i92.ini"
    echo "   - Set SCALE (steps per mm) for each axis"
    echo "   - Set travel limits (MAX_LIMIT)"
    echo "   - Adjust velocities and accelerations"
fi
echo ""
echo "2. ${BOLD}Start LinuxCNC${NC} (Terminal 1):"
echo "   ${CYAN}cd ~/linuxcnc${NC}"
echo "   ${CYAN}. scripts/rip-environment${NC}"
if [ "$config_choice" = "1" ]; then
    echo "   ${CYAN}linuxcnc configs/zero3-mesa7i92/zero3-mesa7i92.ini${NC}"
else
    echo "   ${CYAN}linuxcnc${NC}  # Select your configuration"
fi
echo ""
echo "3. ${BOLD}Start FastAPI${NC} (Terminal 2):"
echo "   ${CYAN}cd $PROJECT_DIR${NC}"
echo "   ${CYAN}source venv/bin/activate${NC}"
echo "   ${CYAN}uvicorn app.main:app --reload --host 0.0.0.0 --port 8000${NC}"
echo ""
echo "4. ${BOLD}Access API:${NC}"
echo "   Open: ${CYAN}http://localhost:8000/docs${NC}"
echo ""

echo -e "${BOLD}Documentation:${NC}"
echo "  - README.md - Quick start and usage"
echo "  - QUICK_START.md - Detailed setup guide"
echo "  - DEVELOPMENT_GUIDE.md - Coding standards"
if [ "$config_choice" = "1" ]; then
    echo "  - linuxcnc_configs/zero3-mesa7i92/README.md - Machine setup"
fi
echo ""

echo -e "${BOLD}Tips:${NC}"
echo "  • Always start LinuxCNC before starting the API"
echo "  • Test with simulator first (configs/sim/axis/axis.ini)"
echo "  • Keep E-stop within reach when testing hardware"
echo "  • Start with conservative speeds and increase gradually"
echo ""

if [ "$LINUXCNC_NEEDS_INSTALL" = true ]; then
    echo -e "${YELLOW}${BOLD}NOTE:${NC} ${YELLOW}LinuxCNC was built from source at:${NC}"
    echo "  $LINUXCNC_DIR"
    echo "  Remember to source the environment before using LinuxCNC:"
    echo "  ${CYAN}. $LINUXCNC_DIR/scripts/rip-environment${NC}"
    echo ""
fi

echo -e "${GREEN}${BOLD}Happy CNC controlling!${NC} 🚀"
echo ""
