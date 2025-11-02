# CNC Control API

A modular FastAPI-based REST API for controlling LinuxCNC CNC machines with Mesa 7i92 Ethernet card.

## Features

- ✅ **Modular Architecture**: Clean separation of concerns (routes, services, models, core)
- ✅ **Complete Documentation**: All functions documented with type hints and docstrings
- ✅ **RESTful API**: Industry-standard REST endpoints with automatic OpenAPI docs
- ✅ **Type Safety**: Full type hints using modern Python 3.10+ syntax
- ✅ **Error Handling**: Custom exceptions with meaningful error codes
- ✅ **Validation**: Pydantic models for request/response validation
- ✅ **Safety Features**: E-stop, homing requirements, coordinate validation
- ✅ **Real LinuxCNC Integration**: Direct connection to LinuxCNC Python API

## Prerequisites

- **Operating System**: Ubuntu 24.04 or similar Debian-based Linux
- **Python**: 3.10 or higher
- **LinuxCNC**: 2.9+ installed and configured
- **Hardware**: Mesa 7i92 card (or use simulator for development)

## Quick Start

### 1. Install LinuxCNC (If Not Already Installed)

```bash
# Install dependencies
sudo apt install -y git build-essential autoconf automake libtool \
    python3-dev python3-tk python3-numpy libreadline-dev \
    libxmu-dev libglu1-mesa-dev libgl1-mesa-dev \
    libgtk2.0-dev libgtk-3-dev libmodbus-dev libusb-1.0-0-dev \
    libudev-dev libjansson-dev libwebsockets-dev libboost-python-dev \
    yapps2 tcl8.6-dev tk8.6-dev asciidoc

# Clone and build LinuxCNC
cd ~
git clone -b 2.9 https://github.com/LinuxCNC/linuxcnc.git
cd linuxcnc/src
./autogen.sh
./configure --with-realtime=uspace --enable-non-distributable=yes
make -j$(nproc)  # Takes 10-30 minutes
sudo make setuid
```

See [QUICK_START.md](QUICK_START.md) for detailed instructions.

### 2. Setup API Project

```bash
# Extract project
unzip cnc_api_project.zip
cd cnc_api_project

# Run automated setup
chmod +x setup.sh
./setup.sh

# Link LinuxCNC to virtual environment
source venv/bin/activate
VENV_SITE=$(python -c "import site; print(site.getsitepackages()[0])")
cat > "$VENV_SITE/linuxcnc.pth" << EOF
$HOME/linuxcnc/lib
$HOME/linuxcnc/lib/python
/usr/lib/python3/dist-packages
EOF

# Verify LinuxCNC is accessible
python -c 'import linuxcnc; print("LinuxCNC OK")'
```

### 3. Start LinuxCNC

**Terminal 1:**
```bash
cd ~/linuxcnc
. scripts/rip-environment
linuxcnc configs/sim/axis/axis.ini  # Or your machine config
```

### 4. Start API

**Terminal 2:**
```bash
cd cnc_api_project
source venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 5. Access API Documentation

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

## Project Structure

```
cnc_api_project/
├── app/
│   ├── main.py                 # FastAPI application
│   ├── config/
│   │   └── settings.py         # Configuration management
│   ├── models/
│   │   ├── requests.py         # Request validation models
│   │   └── responses.py        # Response models
│   ├── services/
│   │   └── cnc_service.py      # Business logic
│   ├── api/
│   │   ├── dependencies.py     # Dependency injection
│   │   └── routes/
│   │       ├── motion.py       # Motion control endpoints
│   │       ├── status.py       # Status endpoints
│   │       └── system.py       # System control endpoints
│   └── core/
│       ├── controller.py       # LinuxCNC wrapper
│       └── exceptions.py       # Custom exceptions
├── config/
│   └── mesa7i92-zero3.hal      # Hardware configuration
├── tests/                      # Unit tests
├── requirements.txt            # Python dependencies
├── .env.example                # Environment template
└── QUICK_START.md             # Detailed setup guide
```

## API Endpoints

### Motion Control

- `POST /motion/absolute` - Move to absolute coordinates
- `POST /motion/relative` - Move relative to current position

### Status Queries

- `GET /status/position` - Get current machine position
- `GET /status/` - Get comprehensive machine status

### System Control

- `POST /system/home` - Home all axes
- `POST /system/estop` - Emergency stop control

## Example Usage

### Using cURL

```bash
# Get machine status
curl http://localhost:8000/status/

# Response:
{
  "position": {"x": 0.0, "y": 0.0, "z": 0.0, "a": 0.0},
  "homed": [true, true, true, true],
  "estop_active": false,
  "machine_on": true,
  "interp_state": 1,
  "feed_rate": 0.0,
  "mock_mode": false
}

# Move to absolute position
curl -X POST http://localhost:8000/motion/absolute \
  -H "Content-Type: application/json" \
  -d '{
    "x": 100.0,
    "y": 50.0,
    "z": 10.0,
    "feed_rate": 1500.0,
    "rapid": false
  }'

# Response:
{
  "success": true,
  "gcode": "G21 G90 G1 X100.0000 Y50.0000 Z10.0000 F1500.0000",
  "message": "Move executed successfully"
}

# Home machine
curl -X POST http://localhost:8000/system/home \
  -H "Content-Type: application/json" \
  -d '{"wait": true}'
```

### Using Python

```python
import httpx

# Get position
response = httpx.get("http://localhost:8000/status/position")
position = response.json()
print(f"Current position: X={position['x']}, Y={position['y']}, Z={position['z']}")

# Move machine
response = httpx.post(
    "http://localhost:8000/motion/absolute",
    json={
        "x": 100.0,
        "y": 50.0,
        "z": 5.0,
        "feed_rate": 1000.0
    }
)
result = response.json()
print(f"Move result: {result['message']}")
print(f"G-code executed: {result['gcode']}")
```

### Using JavaScript

```javascript
// Get machine status
fetch('http://localhost:8000/status/')
  .then(response => response.json())
  .then(data => console.log('Status:', data));

// Move to position
fetch('http://localhost:8000/motion/absolute', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    x: 100.0,
    y: 50.0,
    z: 10.0,
    feed_rate: 1500.0
  })
})
  .then(response => response.json())
  .then(data => console.log('Move result:', data));
```

## HAL File Location

The HAL configuration file is located at `config/mesa7i92-zero3.hal`:

```
cnc_api_project/
└── config/
    └── mesa7i92-zero3.hal  ← Hardware configuration here
```

**Why this location?**
- Separates configuration from code
- Easy to version control
- Supports multiple HAL configurations
- Referenced via `HAL_CONFIG_FILE` in `.env`

## Configuration

Key environment variables in `.env`:

```env
# LinuxCNC
LINUXCNC_PATH=/usr/lib/python3/dist-packages
HAL_CONFIG_FILE=config/mesa7i92-zero3.hal

# API
API_HOST=0.0.0.0
API_PORT=8000

# CNC Settings
DEFAULT_FEED_RATE=1000.0
MAX_FEED_RATE=10000.0

# Safety
REQUIRE_HOMING=true
ENABLE_SOFT_LIMITS=true
```

## Safety Features

- **Homing Required**: Machine must be homed before motion commands
- **E-Stop Control**: Emergency stop via API
- **Coordinate Validation**: Input validation prevents out-of-range moves
- **Error Handling**: Comprehensive error messages with error codes

## Development

### Running Tests

```bash
source venv/bin/activate
pytest                     # Run all tests
pytest --cov=app tests/   # With coverage
pytest tests/test_motion.py -v  # Specific test
```

**Note:** Most tests require a running LinuxCNC instance.

### Code Standards

- Modular design (functions < 50 lines)
- Complete docstrings with `:param` and `:return`
- Full type hints
- Classes for organization

See [DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md) for detailed coding standards.

## Troubleshooting

### "No module named 'linuxcnc'"

**Solution:** Link LinuxCNC to your virtual environment:

```bash
source venv/bin/activate
VENV_SITE=$(python -c "import site; print(site.getsitepackages()[0])")
cat > "$VENV_SITE/linuxcnc.pth" << EOF
$HOME/linuxcnc/lib
$HOME/linuxcnc/lib/python
/usr/lib/python3/dist-packages
EOF
```

### "emcStatusBuffer invalid"

**Solution:** Start LinuxCNC before starting the API.

```bash
# Terminal 1
cd ~/linuxcnc
. scripts/rip-environment
linuxcnc configs/sim/axis/axis.ini
```

### Port Already in Use

**Solution:**
```bash
lsof -ti:8000 | xargs kill -9
# Or change API_PORT in .env
```

## Production Deployment

```bash
# Start LinuxCNC with your machine configuration
cd ~/linuxcnc
. scripts/rip-environment
linuxcnc /path/to/your/machine.ini

# Start API with Gunicorn
cd cnc_api_project
source venv/bin/activate
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

## Documentation

- **[QUICK_START.md](QUICK_START.md)** - Complete setup guide with LinuxCNC installation
- **[DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md)** - Coding standards and best practices
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System architecture diagrams
- **[docs/HAL_FILE_PLACEMENT.md](docs/HAL_FILE_PLACEMENT.md)** - HAL configuration guide

## Contributing

1. Follow coding standards in [DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md)
2. Write tests for new features
3. Update documentation
4. Ensure LinuxCNC integration works
5. Submit PR with clear description

## Architecture

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ HTTP/REST
       ▼
┌─────────────────────────────┐
│      FastAPI Routes         │
│  /motion  /status  /system  │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│       CNC Service           │
│    (Business Logic)         │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│    CNC Controller           │
│  (LinuxCNC Wrapper)         │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│    LinuxCNC Python API      │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│       LinuxCNC Core         │
│       (HAL + RT)            │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│    Mesa 7i92 Hardware       │
│       CNC Machine           │
└─────────────────────────────┘
```

## License

[Your License Here]

## Support

For issues or questions:
- Check [QUICK_START.md](QUICK_START.md) troubleshooting section
- Review [DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md)
- Create an issue in the repository

---

**Important:** This API requires a running LinuxCNC instance. Always start LinuxCNC before starting the API.

**Hardware Safety:** Always test with the simulator before connecting to real CNC hardware.
