# HAL File Placement - Quick Reference

## Location
```
cnc_api_project/
└── config/
    └── mesa7i92-zero3.hal  ← Your HAL file goes here
```

## Why `config/` Directory?

### ✅ Advantages

1. **Clear Separation**
   - Configuration files are distinct from code
   - Easy to identify what's configurable

2. **Version Control**
   - HAL configs can be versioned alongside code
   - Track changes to hardware configuration

3. **Multiple Configurations**
   - Easy to support different machines
   - Example structure:
     ```
     config/
     ├── mesa7i92-zero3.hal      # Main machine
     ├── mesa7i92-test.hal        # Test setup
     └── production-mill.hal      # Production config
     ```

4. **Security**
   - Separate from code execution
   - Can set different permissions
   - Protected by `.gitignore` if needed

5. **Deployment**
   - Easy to swap configurations for different environments
   - Dev/staging/prod configs

## How It's Used in Code

### In `settings.py`:
```python
class Settings(BaseSettings):
    hal_config_file: str = "config/mesa7i92-zero3.hal"
    
    @property
    def hal_config_path(self) -> Path:
        base_path = Path(__file__).parent.parent.parent
        return base_path / self.hal_config_file
```

### In `.env`:
```env
HAL_CONFIG_FILE=config/mesa7i92-zero3.hal
```

## Alternative Locations (Not Recommended)

### ❌ Root Directory
```
cnc_api_project/
└── mesa7i92-zero3.hal  ← Not recommended
```
**Problems**: Clutters root, mixes with Python modules

### ❌ Inside app/ Directory
```
cnc_api_project/
└── app/
    └── mesa7i92-zero3.hal  ← Not recommended
```
**Problems**: Configs shouldn't be inside application code

### ❌ In /etc/ or System Directory
```
/etc/linuxcnc/mesa7i92-zero3.hal  ← Not recommended for development
```
**Problems**: Requires root, not portable, hard to version control

## Best Practices

1. **Keep HAL files in `config/`** directory
2. **Use descriptive names**: `machine-name-board.hal`
3. **Document changes**: Add comments in HAL file
4. **Version control**: Commit HAL files to git
5. **Backup originals**: Keep `.hal.backup` files
6. **Environment variables**: Reference via `.env` for flexibility

## Multiple Machine Support

For supporting multiple machines:

```
config/
├── machines/
│   ├── mill-mesa7i92.hal
│   ├── lathe-mesa5i25.hal
│   └── router-mesa7i76.hal
└── common/
    ├── base-settings.hal
    └── safety-limits.hal
```

Then in `.env`:
```env
MACHINE_TYPE=mill
HAL_CONFIG_FILE=config/machines/${MACHINE_TYPE}-mesa7i92.hal
```

## Summary

**The HAL file belongs in `config/` directory because:**
- ✅ Clean organization
- ✅ Easy to find and modify
- ✅ Supports multiple configurations
- ✅ Proper separation of concerns
- ✅ Easy deployment and version control

**Current location**: `config/mesa7i92-zero3.hal`
