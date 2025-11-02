# CNC API Project Architecture

## 📊 System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Client Applications                   │
│              (Browser, cURL, Python scripts, etc.)          │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTP/REST
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                      FastAPI Application                     │
│                        (app/main.py)                        │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    API Routes Layer                    │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐  │  │
│  │  │   Motion     │  │    Status    │  │   System    │  │  │
│  │  │  /motion/*   │  │  /status/*   │  │ /system/*   │  │  │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬──────┘  │  │
│  └─────────┼──────────────────┼──────────────────┼─────────┘  │
│            │                  │                  │             │
│            └──────────────────┼──────────────────┘             │
│                               ▼                                │
│  ┌───────────────────────────────────────────────────────┐   │
│  │              Service Layer (Business Logic)            │   │
│  │                 app/services/cnc_service.py           │   │
│  │   • execute_absolute_move()                           │   │
│  │   • execute_relative_move()                           │   │
│  │   • home_machine()                                    │   │
│  │   • get_status()                                      │   │
│  └──────────────────────────┬────────────────────────────┘   │
│                             │                                 │
│                             ▼                                 │
│  ┌───────────────────────────────────────────────────────┐   │
│  │             Core Controller Layer                      │   │
│  │              app/core/controller.py                   │   │
│  │   • move_absolute()                                   │   │
│  │   • move_relative()                                   │   │
│  │   • get_current_position()                            │   │
│  │   • home_all_axes()                                   │   │
│  └──────────────────────────┬────────────────────────────┘   │
└─────────────────────────────┼────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    LinuxCNC Python API                       │
│                     (linuxcnc module)                       │
│  • command()  • stat()  • error_channel()                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                      LinuxCNC Core                          │
│                  (Real-time controller)                     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  HAL (Hardware Abstraction Layer)           │
│                  config/mesa7i92-zero3.hal                  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Mesa 7i92 Ethernet Card                  │
│              (Hardware motion controller)                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                     CNC Machine Hardware                     │
│           (Motors, Spindle, E-stop, Limit switches)        │
└─────────────────────────────────────────────────────────────┘
```

## 🔄 Request Flow Example

### Example: Move to Position (X=100, Y=50, Z=10)

```
1. Client Request
   ↓
   POST /motion/absolute
   {
     "x": 100.0,
     "y": 50.0,
     "z": 10.0,
     "feed_rate": 1500.0
   }

2. API Route (app/api/routes/motion.py)
   ↓
   • Validates request with Pydantic models
   • Calls service layer

3. Service Layer (app/services/cnc_service.py)
   ↓
   • Applies business logic
   • Uses default feed_rate if needed
   • Calls controller

4. Controller (app/core/controller.py)
   ↓
   • Checks machine is homed
   • Ensures machine is on
   • Builds G-code: "G21 G90 G1 X100.0000 Y50.0000 Z10.0000 F1500.0000"
   • Sends to LinuxCNC

5. LinuxCNC
   ↓
   • Parses G-code
   • Plans motion
   • Executes through HAL

6. HAL → Mesa 7i92 → Motors
   ↓
   • Motion executed

7. Response
   ↓
   {
     "success": true,
     "gcode": "G21 G90 G1 X100.0000 Y50.0000 Z10.0000 F1500.0000",
     "message": "Move executed successfully"
   }
```

## 📁 Directory Structure Flow

```
cnc_api_project/
│
├── app/                          ← Application code
│   ├── main.py                   ← Entry point, registers routes
│   │
│   ├── api/                      ← API layer
│   │   ├── routes/
│   │   │   ├── motion.py         ← Motion endpoints
│   │   │   ├── status.py         ← Status endpoints
│   │   │   └── system.py         ← System endpoints
│   │   └── dependencies.py       ← Dependency injection
│   │
│   ├── services/                 ← Business logic layer
│   │   └── cnc_service.py        ← CNC operations logic
│   │
│   ├── core/                     ← Core functionality
│   │   ├── controller.py         ← LinuxCNC wrapper
│   │   └── exceptions.py         ← Custom exceptions
│   │
│   ├── models/                   ← Data models
│   │   ├── requests.py           ← Request validation
│   │   └── responses.py          ← Response schemas
│   │
│   └── config/                   ← Configuration
│       └── settings.py           ← App settings
│
├── config/                       ← Hardware configuration
│   └── mesa7i92-zero3.hal        ← HAL file (YOUR FILE IS HERE!)
│
├── tests/                        ← Unit tests
│   └── test_motion.py
│
└── docs/                         ← Documentation
    └── HAL_FILE_PLACEMENT.md
```

## 🔗 Component Dependencies

```
Motion Route ──depends on──> CNC Service ──depends on──> CNC Controller
                                                              │
Status Route ──depends on──> CNC Service ──depends on──┘     │
                                                              │
System Route ──depends on──> CNC Service ──depends on──┘     │
                                                              │
                                                              ▼
                                                      LinuxCNC API
                                                              │
                                                              ▼
                                                      HAL Configuration
                                                              │
                                                              ▼
                                                      Mesa 7i92 Hardware
```

## 🛡️ Error Handling Flow

```
Exception in Controller
         │
         ▼
CNCException (custom exception)
         │
         ▼
Service catches and logs
         │
         ▼
Route handler catches
         │
         ▼
HTTPException raised
         │
         ▼
FastAPI error response
         │
         ▼
Client receives error JSON:
{
  "error": true,
  "error_code": "MACHINE_NOT_HOMED",
  "message": "All axes must be homed before motion commands"
}
```

## 🔐 Dependency Injection

```
FastAPI Request
      │
      ├──> get_cnc_service() (singleton)
      │           │
      │           ├──> CNCService instance
      │           │          │
      │           │          └──> CNCController instance
      │           │                      │
      │           │                      └──> LinuxCNC connection
      │           │
      └──> Route handler receives service
```

## 📦 Data Flow (Models)

```
Client JSON
     │
     ▼
Pydantic Request Model (validates)
     │
     ▼
Service (processes)
     │
     ▼
Controller (executes)
     │
     ▼
Pydantic Response Model (formats)
     │
     ▼
FastAPI (serializes)
     │
     ▼
Client JSON Response
```

This architecture ensures:
✅ **Separation of concerns** - each layer has a specific purpose
✅ **Testability** - easy to mock and test each layer
✅ **Maintainability** - changes in one layer don't break others  
✅ **Scalability** - easy to add new endpoints or features
✅ **Type safety** - Pydantic validates all data
