# CNC API Project - Development Guide

## Project Overview
This is a modular FastAPI-based REST API for controlling a LinuxCNC CNC machine with Mesa 7i92 Ethernet card.

## Prerequisites

### System Requirements
- Ubuntu 24.04 or similar Debian-based Linux
- Python 3.10 or higher
- LinuxCNC 2.9+ installed and configured
- Mesa 7i92 card (or simulator for development)

### LinuxCNC Installation

**Critical:** This API requires a working LinuxCNC installation. The LinuxCNC Python module must be accessible to the API.

#### Option 1: Install from Source (Recommended)

```bash
# Install dependencies
sudo apt install -y git build-essential autoconf automake libtool \
    python3-dev python3-tk python3-numpy libreadline-dev \
    libxmu-dev libglu1-mesa-dev libgl1-mesa-dev \
    libgtk2.0-dev libgtk-3-dev libmodbus-dev libusb-1.0-0-dev \
    libudev-dev libjansson-dev libwebsockets-dev libboost-python-dev \
    yapps2 tcl8.6-dev tk8.6-dev asciidoc

# Clone and build
cd ~
git clone -b 2.9 https://github.com/LinuxCNC/linuxcnc.git
cd linuxcnc/src
./autogen.sh
./configure --with-realtime=uspace --enable-non-distributable=yes
make -j$(nproc)
sudo make setuid

# Verify
cd ~/linuxcnc
. scripts/rip-environment
python3 -c 'import linuxcnc; print("LinuxCNC OK")'
```

#### Option 2: Install from Package

```bash
sudo apt install linuxcnc-uspace
```

## Project Structure
```
cnc_api_project/
├── app/
│   ├── __init__.py
│   ├── main.py                 # FastAPI application entry point
│   ├── config/
│   │   ├── __init__.py
│   │   ├── settings.py         # Application configuration
│   │   └── hal_config.py       # HAL configuration manager (future)
│   ├── models/
│   │   ├── __init__.py
│   │   ├── requests.py         # Pydantic request models
│   │   └── responses.py        # Pydantic response models
│   ├── services/
│   │   ├── __init__.py
│   │   └── cnc_service.py      # CNC controller business logic
│   ├── api/
│   │   ├── __init__.py
│   │   ├── routes/
│   │   │   ├── __init__.py
│   │   │   ├── motion.py       # Motion control endpoints
│   │   │   ├── status.py       # Status query endpoints
│   │   │   └── system.py       # System control endpoints
│   │   └── dependencies.py     # FastAPI dependencies
│   └── core/
│       ├── __init__.py
│       ├── controller.py       # LinuxCNC controller wrapper
│       └── exceptions.py       # Custom exceptions
├── config/
│   └── mesa7i92-zero3.hal      # HAL hardware configuration
├── tests/
│   ├── __init__.py
│   ├── test_motion.py
│   └── test_status.py
├── docs/
│   └── api_documentation.md
├── requirements.txt
├── .env.example
├── .gitignore
├── README.md
└── DEVELOPMENT_GUIDE.md        # This file
```

## Initial Setup

### 1. Clone/Extract Project

```bash
unzip cnc_api_project.zip
cd cnc_api_project
```

### 2. Run Setup Script

```bash
chmod +x setup.sh
./setup.sh
```

The setup script will:
- Create virtual environment
- Install Python dependencies
- Link LinuxCNC Python module to venv (if available)
- Create .env file

### 3. Manual LinuxCNC Linking (If Needed)

If setup.sh didn't successfully link LinuxCNC:

```bash
source venv/bin/activate

# Get venv site-packages path
VENV_SITE=$(python -c "import site; print(site.getsitepackages()[0])")

# Create .pth file with LinuxCNC paths
cat > "$VENV_SITE/linuxcnc.pth" << EOF
/home/$USER/linuxcnc/lib
/home/$USER/linuxcnc/lib/python
/usr/lib/python3/dist-packages
EOF

# Verify
python -c 'import linuxcnc; print("Success!")'
```

### 4. Configure Environment

Edit `.env` file:
```bash
nano .env
```

Key settings:
```env
LINUXCNC_PATH=/usr/lib/python3/dist-packages
HAL_CONFIG_FILE=config/mesa7i92-zero3.hal
API_PORT=8000
DEFAULT_FEED_RATE=1000.0
```

## Running the Application

### Development Mode

**Two terminals required:**

**Terminal 1: LinuxCNC**
```bash
cd ~/linuxcnc
. scripts/rip-environment

# For testing without hardware (simulator)
linuxcnc configs/sim/axis/axis.ini

# For actual machine
# linuxcnc /path/to/your/config.ini
```

**Terminal 2: API**
```bash
cd cnc_api_project
source venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Production Mode

```bash
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

## Coding Standards

### 1. Modular Design
- **No long functions**: Maximum 50 lines per function
- **Single Responsibility**: Each class/function should have one clear purpose
- **Use classes**: Organize related functionality into classes
- **Separation of concerns**: API routes, business logic, and data access should be separate

### 2. Documentation Requirements

#### Function Documentation
All functions must include complete docstrings with:
- Brief description
- `:param` for each parameter with type and description
- `:return:` for return value with type and description
- `:raises:` for exceptions that may be raised

Example:
```python
def move_to_position(
    self,
    x: float | None = None,
    y: float | None = None,
    z: float | None = None,
    feed_rate: float = 1000.0
) -> dict[str, Any]:
    """
    Move CNC machine to specified coordinates.
    
    :param x: X-axis target position in mm (None to skip)
    :type x: float | None
    :param y: Y-axis target position in mm (None to skip)
    :type y: float | None
    :param z: Z-axis target position in mm (None to skip)
    :type z: float | None
    :param feed_rate: Feed rate in mm/min
    :type feed_rate: float
    :return: Dictionary with move status and executed G-code
    :rtype: dict[str, Any]
    :raises RuntimeError: If machine is not homed or E-stop is active
    :raises ValueError: If feed_rate is invalid
    """
    # Implementation
```

#### Type Hints
- **Required**: All function parameters and return values must have type hints
- Use modern Python 3.10+ syntax: `list[str]`, `dict[str, int]`, `int | None`
- For complex types, use `typing` module: `Optional`, `Union`, `TypeVar`, etc.

### 3. Class Design
```python
class ExampleService:
    """Service for handling example operations."""
    
    def __init__(self, config: Config) -> None:
        """
        Initialize the service.
        
        :param config: Application configuration
        :type config: Config
        """
        self._config = config
    
    def process_data(self, data: dict[str, Any]) -> ProcessResult:
        """
        Process input data and return result.
        
        :param data: Input data dictionary
        :type data: dict[str, Any]
        :return: Processing result
        :rtype: ProcessResult
        :raises ValidationError: If data is invalid
        """
        # Implementation broken into smaller methods
        validated = self._validate_data(data)
        transformed = self._transform_data(validated)
        return self._create_result(transformed)
    
    def _validate_data(self, data: dict[str, Any]) -> dict[str, Any]:
        """Validate input data (private helper)."""
        # Keep this under 20 lines
        pass
```

## Virtual Environment Setup

### Initial Setup
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Development Workflow
```bash
# Always activate venv before working
source venv/bin/activate

# Install new packages
pip install package_name

# Update requirements.txt
pip freeze > requirements.txt

# Deactivate when done
deactivate
```

## HAL File Placement

### Location: `config/mesa7i92-zero3.hal`

**Rationale:**
- HAL files are configuration, not code
- Separate `config/` directory keeps hardware configs distinct
- Easy to version control and swap configurations
- Can support multiple HAL configs (e.g., different machines)

### Usage in Code
```python
from pathlib import Path

# Load HAL config path
HAL_CONFIG_DIR = Path(__file__).parent.parent / "config"
HAL_FILE = HAL_CONFIG_DIR / "mesa7i92-zero3.hal"
```

## Testing

```bash
# Activate venv
source venv/bin/activate

# Run all tests
pytest

# Run with coverage
pytest --cov=app tests/

# Run specific test file
pytest tests/test_motion.py -v
```

**Note:** Most tests require a running LinuxCNC instance.

## API Documentation
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Troubleshooting

### "No module named 'linuxcnc'"

**Cause:** Virtual environment can't find LinuxCNC module

**Solution:**
1. Verify LinuxCNC is installed:
   ```bash
   python3 -c "import linuxcnc"
   ```
2. Re-link to venv (see Initial Setup section 3)

### "emcStatusBuffer invalid"

**Cause:** LinuxCNC is not running

**Solution:** Start LinuxCNC before starting the API

### Import Errors After Installing Packages

**Cause:** Package conflicts or missing dependencies

**Solution:**
```bash
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt --force-reinstall
```

## Git Workflow
```bash
# Feature branch
git checkout -b feature/new-endpoint

# Commit with descriptive message
git commit -m "feat: add emergency stop endpoint"

# Push and create PR
git push origin feature/new-endpoint
```

## Code Review Checklist
- [ ] All functions have complete docstrings
- [ ] All parameters have type hints
- [ ] No function exceeds 50 lines
- [ ] Classes are used appropriately
- [ ] Errors have proper exception handling
- [ ] Tests are included for new features
- [ ] README is updated if needed
- [ ] LinuxCNC must be running for integration tests

## Dependencies
See `requirements.txt` for full list. Key dependencies:
- `fastapi` - Web framework
- `uvicorn` - ASGI server
- `pydantic` - Data validation
- `python-dotenv` - Environment variables
- `pytest` - Testing framework

**System dependency:** LinuxCNC Python module (installed separately)

## Environment Variables
Key variables in `.env`:
```env
# LinuxCNC
LINUXCNC_PATH=/usr/lib/python3/dist-packages
HAL_CONFIG_FILE=config/mesa7i92-zero3.hal

# API
API_HOST=0.0.0.0
API_PORT=8000
LOG_LEVEL=INFO

# CNC
DEFAULT_FEED_RATE=1000.0
MAX_FEED_RATE=10000.0
POLL_INTERVAL=0.05

# Safety
REQUIRE_HOMING=true
ENABLE_SOFT_LIMITS=true
```

## Contributing
1. Follow the coding standards above
2. Write tests for new features
3. Update documentation
4. Submit PR with clear description
5. Ensure LinuxCNC integration works

## Real Hardware vs Simulator

### Simulator (Development)
```bash
# Safe for development without hardware
linuxcnc configs/sim/axis/axis.ini
```

### Real Hardware (Production)
```bash
# Use your actual machine configuration
linuxcnc /path/to/your/machine.ini

# Ensure HAL file in config/ matches your hardware
```

---

**Last Updated:** 2025-11-02

**Key Takeaway:** Always ensure LinuxCNC is running before starting the API. The API is a client that connects to a running LinuxCNC instance.
