# LinuxCNC Machine Configurations

This directory contains pre-configured LinuxCNC setups for different CNC machines.

## Available Configurations

### 1. Zero-3 with Mesa 7i92 (`zero3-mesa7i92/`)

**Hardware:**
- Controller: HighZ Zero-3
- Interface: Mesa 7i92 Ethernet FPGA card
- Axes: X, Y, Z (optionally A)

**Features:**
- Step/Dir control via Mesa 7i92
- Spindle PWM control
- Charge pump watchdog
- E-stop and home switches
- Relay outputs for spindle/coolant

**Setup:**
```bash
cd ~/linuxcnc/configs/
cp -r /path/to/project/linuxcnc_configs/zero3-mesa7i92 .
```

See [docs/LINUXCNC_ZERO3_SETUP.md](../docs/LINUXCNC_ZERO3_SETUP.md) for complete setup guide.

---

### 2. Generic Step/Dir (Coming Soon)

**Hardware:**
- Any parallel port step/dir controller
- Standard breakout board

---

### 3. Mesa 5i25 + 7i76 (Coming Soon)

**Hardware:**
- Mesa 5i25 PCI card
- Mesa 7i76 I/O daughter card

---

## Adding Your Own Configuration

### Option 1: During Setup

Run the setup script and choose option 2 (Custom configuration):
```bash
./setup.sh
```

### Option 2: Manual Addition

1. Create directory structure:
```bash
mkdir -p linuxcnc_configs/your-machine
```

2. Add your configuration files:
```
linuxcnc_configs/your-machine/
├── your-machine.ini          # Main configuration
├── your-machine.hal          # Hardware abstraction
├── custom_postgui.hal        # Custom HAL (optional)
├── postgui.hal               # Post-GUI HAL (optional)
└── README.md                 # Setup instructions
```

3. Document your configuration:
   - Hardware requirements
   - Wiring diagram
   - Pin mappings
   - Setup steps
   - Tuning parameters

4. Submit a pull request to add to the project!

## Configuration File Requirements

Each machine configuration must include:

### Required Files:
- **`machine-name.ini`** - LinuxCNC INI file with all parameters
- **`machine-name.hal`** - HAL file connecting hardware to LinuxCNC
- **`README.md`** - Setup instructions specific to this machine

### Optional Files:
- `custom_postgui.hal` - Additional HAL after GUI loads
- `postgui.hal` - Post-GUI HAL commands
- `tool.tbl` - Tool table
- `*.ngc` - Sample G-code programs

### Auto-created Files:
- `linuxcnc.var` - G-code variables (auto-created)
- `position.txt` - Last known position (auto-created)

## Testing Your Configuration

Before adding a configuration:

1. **Test with LinuxCNC:**
   ```bash
   cd ~/linuxcnc
   . scripts/rip-environment
   linuxcnc configs/your-machine/your-machine.ini
   ```

2. **Verify all components:**
   - Motors move in correct direction
   - Home switches work
   - E-stop functions properly
   - Spindle control works
   - No HAL errors

3. **Test with API:**
   ```bash
   # Start LinuxCNC first, then:
   uvicorn app.main:app --reload
   curl http://localhost:8000/status/
   ```

4. **Document any quirks or special requirements**

## Configuration Template

See `zero3-mesa7i92/` as a reference template for creating new configurations.

## Contributing

To contribute a new machine configuration:

1. Fork the repository
2. Add your configuration to `linuxcnc_configs/`
3. Include complete documentation
4. Test thoroughly
5. Submit pull request

**Include in PR description:**
- Hardware details
- Photos/diagrams (if possible)
- Tested LinuxCNC version
- Any special requirements

## Support

For help with:
- **Existing configurations:** Create an issue on GitHub
- **New configurations:** Start a discussion on GitHub
- **LinuxCNC general help:** http://linuxcnc.org/docs/

## File Organization

```
linuxcnc_configs/
├── README.md                    # This file
├── zero3-mesa7i92/             # Zero-3 configuration
│   ├── README.md
│   ├── zero3-mesa7i92.ini
│   ├── mesa7i92-zero3.hal
│   ├── custom_postgui.hal
│   └── postgui.hal
├── generic-parallel-port/       # Future: Generic parport
│   └── ...
└── mesa-5i25-7i76/             # Future: Mesa combo
    └── ...
```

## Integration with Setup Script

The `setup.sh` script automatically:
1. Detects available configurations
2. Lets user choose which to install
3. Copies files to `~/linuxcnc/configs/`
4. Creates required empty files
5. Updates `.env` with correct paths

## Best Practices

When creating configurations:

1. **Use descriptive names:**
   - Good: `tormach-770-mesa7i76`
   - Bad: `my-machine`

2. **Document everything:**
   - Pin assignments
   - Wiring colors
   - Calculated values (steps/mm)

3. **Include comments in HAL/INI files:**
   - Explain non-obvious settings
   - Note hardware-specific requirements

4. **Provide safe defaults:**
   - Conservative velocities
   - Lower accelerations
   - User can tune up later

5. **Test thoroughly:**
   - All axes
   - All I/O
   - Emergency stops
   - Limit switches

## License

All configurations in this directory are provided under the same license as the main project.

---

**Need help creating a configuration?** Open an issue on GitHub!
