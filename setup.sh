#!/bin/bash
# Setup script for CNC API Project with LinuxCNC integration

set -e

echo "========================================="
echo "CNC API Project Setup"
echo "========================================="
echo ""

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.10 or higher."
    exit 1
fi

echo "✓ Python 3 found: $(python3 --version)"
echo ""

# Check if LinuxCNC is available
echo "Checking for LinuxCNC installation..."
if python3 -c "import linuxcnc" 2>/dev/null; then
    echo "✓ LinuxCNC Python module found"
    LINUXCNC_AVAILABLE=true
else
    echo "⚠ LinuxCNC Python module not found"
    echo ""
    echo "LinuxCNC needs to be installed for this API to work."
    echo ""
    echo "Options:"
    echo "1. Install from source (recommended):"
    echo "   See QUICK_START.md Part 1 for instructions"
    echo ""
    echo "2. Install from package (if available for your distribution):"
    echo "   sudo apt install linuxcnc-uspace"
    echo ""
    LINUXCNC_AVAILABLE=false
fi
echo ""

# Create virtual environment
echo "📦 Creating virtual environment..."
python3 -m venv venv

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "⬆️  Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo "📥 Installing dependencies..."
pip install -r requirements.txt

# Link LinuxCNC to virtual environment if available
if [ "$LINUXCNC_AVAILABLE" = true ]; then
    echo ""
    echo "🔗 Linking LinuxCNC to virtual environment..."
    
    VENV_SITE=$(python -c "import site; print(site.getsitepackages()[0])")
    echo "   Virtual environment site-packages: $VENV_SITE"
    
    # Try to find LinuxCNC location
    LINUXCNC_PATHS=""
    
    # Check common locations
    if [ -d "$HOME/linuxcnc/lib" ]; then
        LINUXCNC_PATHS="$HOME/linuxcnc/lib
$HOME/linuxcnc/lib/python"
        echo "   Found LinuxCNC in: $HOME/linuxcnc"
    fi
    
    # Add system packages
    LINUXCNC_PATHS="$LINUXCNC_PATHS
/usr/lib/python3/dist-packages
/usr/lib/python3.12/dist-packages"
    
    # Create .pth file
    echo "$LINUXCNC_PATHS" > "$VENV_SITE/linuxcnc.pth"
    
    # Verify it works
    if python -c "import linuxcnc" 2>/dev/null; then
        echo "   ✓ LinuxCNC successfully linked to virtual environment"
    else
        echo "   ⚠ Warning: LinuxCNC still not accessible in venv"
        echo "   You may need to manually configure the path. See QUICK_START.md Step 4"
    fi
fi

# Create .env from example
if [ ! -f .env ]; then
    echo ""
    echo "📝 Creating .env file from example..."
    cp .env.example .env
    echo "✓ .env file created. Please edit it with your configuration."
else
    echo ""
    echo "⚠️  .env file already exists, skipping..."
fi

# Check for .env.example
if [ ! -f .env.example ]; then
    echo ""
    echo "⚠️  .env.example missing. Creating it now..."
    cat > .env.example << 'EOF'
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
    echo "✓ .env.example created"
fi

echo ""
echo "========================================="
echo "✅ Setup Complete!"
echo "========================================="
echo ""

if [ "$LINUXCNC_AVAILABLE" = false ]; then
    echo "⚠️  IMPORTANT: LinuxCNC is not installed!"
    echo ""
    echo "The API requires LinuxCNC to function. Please:"
    echo "1. Install LinuxCNC (see QUICK_START.md Part 1)"
    echo "2. Re-run this setup script"
    echo ""
fi

echo "Next steps:"
echo ""
echo "1. Edit .env file with your LinuxCNC configuration"
echo "   nano .env"
echo ""
echo "2. Start LinuxCNC first (in a separate terminal):"
echo "   cd ~/linuxcnc"
echo "   . scripts/rip-environment"
echo "   linuxcnc configs/sim/axis/axis.ini"
echo ""
echo "3. Activate virtual environment:"
echo "   source venv/bin/activate"
echo ""
echo "4. Run the API:"
echo "   uvicorn app.main:app --reload"
echo ""
echo "5. Visit http://localhost:8000/docs for API documentation"
echo ""
echo "For detailed documentation, see:"
echo "- QUICK_START.md - Complete setup guide"
echo "- README.md - API usage and examples"
echo "- DEVELOPMENT_GUIDE.md - Coding standards"
echo ""

if [ "$LINUXCNC_AVAILABLE" = true ]; then
    echo "========================================="
    echo "✓ System Ready!"
    echo "========================================="
fi
