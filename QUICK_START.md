# ⚡ Quick Start Guide

## Prerequisites

Before starting, you need:
- Ubuntu 24.04 or similar Debian-based Linux
- Python 3.10 or higher
- LinuxCNC installed (see below if not installed)

## Part 1: Install LinuxCNC (If Not Already Installed)

### Check if LinuxCNC is Already Installed

```bash
python3 -c "import linuxcnc; print('LinuxCNC already installed!')" 2>/dev/null
```

If this works, **skip to Part 2**. Otherwise, continue:

### Install LinuxCNC from Source

```bash
# 1. Install build dependencies
sudo apt install -y git build-essential autoconf automake libtool \
    python3-dev python3-tk python3-numpy libreadline-dev \
    libxmu-dev libglu1-mesa-dev libgl1-mesa-dev \
    libgtk2.0-dev libgtk-3-dev libmodbus-dev libusb-1.0-0-dev \
    libudev-dev libjansson-dev libwebsockets-dev libboost-python-dev \
    yapps2 tcl8.6-dev tk8.6-dev asciidoc

# 2. Clone LinuxCNC (if not already cloned)
cd ~
git clone -b 2.9 https://github.com/LinuxCNC/linuxcnc.git

# 3. Build LinuxCNC (takes 10-30 minutes)
cd ~/linuxcnc/src
./autogen.sh
./configure --with-realtime=uspace --enable-non-distributable=yes
make -j$(nproc)
sudo make setuid

# 4. Set up environment
cd ~/linuxcnc
. scripts/rip-environment

# 5. Verify installation
python3 -c 'import linuxcnc; print("LinuxCNC installed successfully!")'
```

**Note:** You'll need to run `. ~/linuxcnc/scripts/rip-environment` in each terminal session before using LinuxCNC.

## Part 2: Setup CNC API Project

### Step 1: Extract Project

```bash
# If you have the zip file
unzip cnc_api_project.zip
cd cnc_api_project

# Or if you have tar.gz
tar -xzf cnc_api_project.tar.gz
cd cnc_api_project
```

### Step 2: Create Missing Files (If Needed)

Hidden files may not extract properly. Create them:

```bash
# Create .env.example if missing
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

# Create .gitignore if missing
cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
venv/
.env
.env.local

# FastAPI
.pytest_cache/
*.log

# IDE
.vscode/
.idea/
EOF
```

### Step 3: Run Setup Script

```bash
# Make setup.sh executable
chmod +x setup.sh

# Run setup (creates venv and installs dependencies)
./setup.sh
```

### Step 4: Link LinuxCNC to Virtual Environment

This is **critical** - your venv needs to find the LinuxCNC module:

```bash
# Activate virtual environment
source venv/bin/activate

# Get venv's site-packages directory
VENV_SITE=$(python -c "import site; print(site.getsitepackages()[0])")

# Add LinuxCNC paths
cat > "$VENV_SITE/linuxcnc.pth" << EOF
/home/$USER/linuxcnc/lib
/home/$USER/linuxcnc/lib/python
/usr/lib/python3/dist-packages
EOF

# Verify LinuxCNC is accessible
python -c 'import linuxcnc; print("✓ LinuxCNC accessible in venv")'
```

If the verification fails, check:
```bash
# Find where linuxcnc actually is
find ~ -name "linuxcnc.so" 2>/dev/null

# Update the .pth file with the correct path
```

### Step 5: Configure Environment

```bash
# Copy example to actual .env
cp .env.example .env

# Edit if needed (usually defaults are fine)
nano .env
```

### Step 6: Start LinuxCNC

**Important:** The API needs a running LinuxCNC instance to connect to.

**Terminal 1 - Start LinuxCNC:**
```bash
cd ~/linuxcnc
. scripts/rip-environment

# Start with simulator (for testing without hardware)
linuxcnc configs/sim/axis/axis.ini

# OR start with your actual machine config
# linuxcnc /path/to/your/machine.ini
```

### Step 7: Start the API

**Terminal 2 - Start API:**
```bash
cd ~/path/to/cnc_api_project
source venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

You should see:
```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete.
✓ Connected to real LinuxCNC
```

### Step 8: Test the API

Open browser to: **http://localhost:8000/docs**

Or test with curl:
```bash
# Get machine status
curl http://localhost:8000/status/

# Expected response:
{
  "position": {"x": 0.0, "y": 0.0, "z": 0.0, "a": 0.0},
  "homed": [true, true, true, true],
  "estop_active": false,
  "machine_on": true,
  "mock_mode": false
}
```

## Common Issues

### Issue 1: "No module named 'linuxcnc'"

**Solution:** LinuxCNC isn't accessible to your venv. Redo Step 4 above.

### Issue 2: "emcStatusBuffer invalid"

**Solution:** LinuxCNC isn't running. Start LinuxCNC first (Step 6).

### Issue 3: "Port 8000 already in use"

**Solution:**
```bash
# Kill process on port 8000
lsof -ti:8000 | xargs kill -9

# Or change port in .env
echo "API_PORT=8001" >> .env
```

### Issue 4: Hidden files (.env.example) missing

**Solution:** Manually create them using the commands in Step 2.

## Development Workflow

### Daily Development

```bash
# Terminal 1: LinuxCNC
cd ~/linuxcnc && . scripts/rip-environment
linuxcnc configs/sim/axis/axis.ini

# Terminal 2: API
cd ~/cnc_api_project
source venv/bin/activate
uvicorn app.main:app --reload
```

### Making Changes

The API will auto-reload when you edit Python files thanks to `--reload` flag.

## Next Steps

- ✅ Read [README.md](README.md) for API usage examples
- ✅ Read [DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md) for coding standards
- ✅ Check [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for system design
- ✅ View interactive API docs at http://localhost:8000/docs

## For Production Use

1. Start LinuxCNC with your actual machine configuration
2. Update `HAL_CONFIG_FILE` in `.env` to point to your HAL file
3. Use gunicorn instead of uvicorn:
   ```bash
   gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
   ```

---

**You're ready to develop!** 🚀

The key points:
1. LinuxCNC must be built and accessible
2. Virtual environment must have LinuxCNC in its path (.pth file)
3. LinuxCNC must be running before starting the API
