# Zero-3 CNC with Mesa 7i92 Configuration

LinuxCNC configuration for HighZ Zero-3 CNC controller with Mesa 7i92 Ethernet FPGA card.

## Hardware Overview

- **CNC Controller:** HighZ Zero-3
- **Motion Control:** Mesa 7i92 Ethernet FPGA card
- **Axes:** X, Y, Z (optionally A/C)
- **Spindle:** PWM control + relay
- **I/O:** E-stop, home switches, coolant relay

## Files in This Configuration

- `zero3-mesa7i92.ini` - Main LinuxCNC configuration file
- `mesa7i92-zero3.hal` - Hardware abstraction layer
- `custom_postgui.hal` - Custom HAL code (add your own)
- `postgui.hal` - Post-GUI HAL commands
- `linuxcnc.var` - G-code variables (auto-created)
- `position.txt` - Position memory (auto-created)

## Quick Start

### 1. Installation

The setup script (`setup.sh`) can install this automatically, or manually:

```bash
# Copy configuration
cp -r linuxcnc_configs/zero3-mesa7i92 ~/linuxcnc/configs/

# Create required empty files (if not exist)
cd ~/linuxcnc/configs/zero3-mesa7i92
touch custom_postgui.hal postgui.hal linuxcnc.var position.txt
```

### 2. Network Setup

Configure your PC's network interface for Mesa 7i92:

```bash
# Find your ethernet interface
ip addr

# Configure static IP (replace enp0s31f6 with your interface)
sudo ip addr add 192.168.192.1/24 dev enp0s31f6
sudo ip link set enp0s31f6 up

# Test connection
ping 192.168.192.210
```

### 3. Configure Machine Parameters

Edit `zero3-mesa7i92.ini`:

#### A. Steps per mm (CRITICAL!)

Calculate for each axis:
```
SCALE = (motor_steps_per_rev × microstepping) / mm_per_revolution
```

**Example for 5mm pitch ball screw:**
```
SCALE = (200 steps × 10 microsteps) / 5mm = 400 steps/mm
```

Update in INI file:
```ini
[JOINT_0]
SCALE = 400.0  # Your calculated X value

[JOINT_1]
SCALE = 400.0  # Your calculated Y value

[JOINT_2]
SCALE = 400.0  # Your calculated Z value
```

#### B. Travel Limits

Measure your machine and update:
```ini
[JOINT_0]
MIN_LIMIT = -0.01
MAX_LIMIT = 400.0      # X travel in mm

[JOINT_1]
MIN_LIMIT = -0.01
MAX_LIMIT = 400.0      # Y travel in mm

[JOINT_2]
MIN_LIMIT = -100.0     # Z travel (negative)
MAX_LIMIT = 0.01
```

#### C. Velocities (Start Conservative!)

```ini
[JOINT_0]
MAX_VELOCITY = 50.0         # mm/s (increase after testing)
MAX_ACCELERATION = 500.0    # mm/s² (increase after testing)
```

### 4. Start LinuxCNC

```bash
cd ~/linuxcnc
. scripts/rip-environment
linuxcnc configs/zero3-mesa7i92/zero3-mesa7i92.ini
```

## Pin Assignments

### Mesa 7i92 P2 Connector

| Pin | Function | Connection |
|-----|----------|------------|
| P2-2 | X Step | Zero-3 X Step |
| P2-3 | X Dir | Zero-3 X Dir |
| P2-4 | Y Step | Zero-3 Y Step |
| P2-5 | Y Dir | Zero-3 Y Dir |
| P2-6 | Z Step | Zero-3 Z Step |
| P2-7 | Z Dir | Zero-3 Z Dir |
| P2-8 | A Step | Zero-3 A Step (optional) |
| P2-9 | A Dir | Zero-3 A Dir (optional) |
| P2-1 | GPIO 000 | Spindle Relay |
| P2-14 | GPIO 001 | Coolant/Vacuum Relay |
| P2-17 | PWM 0 | Spindle Speed (PWM) |
| P2-16 | StepGen 4 | Charge Pump (12.5kHz) |
| P2-11 | GPIO 014 | E-Stop (active-low) |
| P2-10 | GPIO 013 | Z Home Switch |
| P2-12 | GPIO 015 | Y Home Switch |
| P2-13 | GPIO 016 | X Home Switch |

## Testing Procedure

### Phase 1: Power-Up

1. Start LinuxCNC
2. Check terminal for errors
3. Verify Mesa LED blinks (communication active)
4. Press F1 (E-stop off) then F2 (Machine on)

### Phase 2: E-Stop Test

1. Press physical E-stop button
2. LinuxCNC should show E-stop active
3. Release E-stop
4. Should be able to re-enable machine

**If inverted:** E-stop logic may need adjustment in HAL file

### Phase 3: Home Switch Test

1. Open: Machine → Show HAL Configuration
2. Find signals: `gpio.013.in`, `gpio.015.in`, `gpio.016.in`
3. Manually trigger each home switch
4. Verify signals go TRUE in HAL meter

**If not working:**
- Check wiring (NC vs NO switches)
- May need to invert: `setp hm2_7i92.0.gpio.XXX.invert_input true`

### Phase 4: Motor Direction Test

⚠️ **IMPORTANT: Remove Z axis drive belt first!**

1. Home machine or bypass homing for initial test
2. Jog X axis +1mm
   - Should move **right** (positive direction)
   - If wrong: negate SCALE in INI (e.g., `SCALE = -400.0`)
3. Jog Y axis +1mm
   - Should move **away from you** (back)
   - If wrong: negate SCALE
4. Jog Z axis +1mm
   - Should move **up**
   - If wrong: negate SCALE

### Phase 5: Spindle Test

1. In LinuxCNC, turn on spindle (S1000 M3)
2. Verify:
   - Relay clicks (spindle power)
   - PWM signal present on P2-17
   - Speed changes with S-word

## Common Issues

### "board_ip=192.168.192.210 failed to connect"

**Cause:** Network not configured or Mesa not reachable

**Solutions:**
1. Check ethernet cable
2. Verify Mesa power
3. Check network config: `ip addr`
4. Ping test: `ping 192.168.192.210`
5. Try different Mesa IP (check with `mesaflash`)

### Motors Don't Move

**Possible causes:**
1. Enable signal not active
   - Check HAL: `hm2_7i92.0.stepgen.XX.enable` should be TRUE
2. Zero-3 not powered
3. Cable issue
4. Wrong wiring

**Debug:**
- Use HAL meter to check signals
- Verify stepgen position-cmd is changing
- Check Zero-3 LED indicators

### Wrong Direction

**Solution:** Negate SCALE value in INI file
```ini
# If X moves left instead of right:
SCALE = -400.0  # Was 400.0
```

### Home Switches Inverted

**Solution:** Add to HAL file:
```hal
setp hm2_7i92.0.gpio.013.invert_input true  # Z home
setp hm2_7i92.0.gpio.015.invert_input true  # Y home
setp hm2_7i92.0.gpio.016.invert_input true  # X home
```

### Charge Pump Not Working

**Debug:**
- Use oscilloscope on P2-16
- Should see 12.5 kHz square wave
- Check Zero-3 charge pump input requirements

### "Unexpected realtime delay"

**Cause:** CPU too slow or too busy

**Solutions:**
1. Close unnecessary programs
2. Increase servo period in INI (e.g., 1ms → 2ms)
3. Check CPU load

## Tuning Parameters

After initial testing works:

### 1. Increase Velocities Gradually

Start at 50mm/s, test, then increase:
```ini
MAX_VELOCITY = 50.0   # Test
MAX_VELOCITY = 75.0   # Test
MAX_VELOCITY = 100.0  # Test
```

### 2. Tune Accelerations

```ini
MAX_ACCELERATION = 500.0   # Start conservative
# Increase gradually while testing for:
# - No stalling
# - No excessive vibration
# - Smooth motion
```

### 3. Optimize Homing

Adjust homing speeds:
```ini
HOME_SEARCH_VEL = 5.0   # Initial search speed
HOME_LATCH_VEL = 1.0    # Final approach speed
HOME_FINAL_VEL = 10.0   # Speed to home position
```

## Advanced: Custom HAL

Add custom functionality in `custom_postgui.hal`:

### Example: Add Probe Input

```hal
# Probe input on P2-15 (GPIO 002)
net probe-in <= hm2_7i92.0.gpio.002.in
net probe-in => motion.probe-input
```

### Example: Add Pause Button

```hal
loadrt toggle count=1
addf toggle.0 servo-thread

net pause-btn <= hm2_7i92.0.gpio.XXX.in
net pause-btn => toggle.0.in
net pause-out <= toggle.0.out
net pause-out => halui.program.pause
```

## Integration with FastAPI

Once LinuxCNC is running with this config:

```bash
# Terminal 1: LinuxCNC
cd ~/linuxcnc
. scripts/rip-environment
linuxcnc configs/zero3-mesa7i92/zero3-mesa7i92.ini

# Terminal 2: FastAPI
cd /path/to/cnc_api_project
source venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Terminal 3: Test
curl http://localhost:8000/status/
```

## Maintenance

### Backup Your Tuned Configuration

```bash
cd ~/linuxcnc/configs
tar -czf zero3-backup-$(date +%Y%m%d).tar.gz zero3-mesa7i92/
```

### Update Configuration

When updating from git:
1. Backup your tuned INI file
2. Copy new version
3. Merge your custom parameters

## Support Resources

- **HighZ Zero-3 Manual:** See project `docs/` folder
- **Mesa 7i92 Manual:** http://www.mesanet.com/pdf/parallel/7i92man.pdf
- **LinuxCNC HAL Docs:** http://linuxcnc.org/docs/html/hal/intro.html
- **LinuxCNC Forum:** https://forum.linuxcnc.org/

## Safety Warnings

⚠️ **ALWAYS:**
- Test without drive belts first
- Keep E-stop within reach
- Start with low speeds
- Verify soft limits
- Never leave machine unattended

## License

This configuration is part of the CNC FastAPI project and shares the same license.

---

**Questions?** Open an issue on GitHub or consult the main documentation.
