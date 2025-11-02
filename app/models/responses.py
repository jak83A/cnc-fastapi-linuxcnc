"""
Pydantic models for API responses.
"""
from pydantic import BaseModel, Field
from typing import Any


class PositionResponse(BaseModel):
    """Response model for position queries."""
    
    x: float = Field(..., description="X-axis position in mm")
    y: float = Field(..., description="Y-axis position in mm")
    z: float = Field(..., description="Z-axis position in mm")
    a: float = Field(..., description="A-axis position in degrees")


class MachineStatusResponse(BaseModel):
    """Response model for comprehensive machine status."""
    
    position: PositionResponse
    homed: list[bool] = Field(..., description="Homing status for each joint")
    estop_active: bool = Field(..., description="Emergency stop status")
    machine_on: bool = Field(..., description="Machine power status")
    interp_state: int = Field(..., description="Interpreter state code")
    feed_rate: float = Field(..., description="Current feed rate in mm/min")


class MoveResponse(BaseModel):
    """Response model for movement commands."""
    
    success: bool = Field(..., description="Whether move was successful")
    gcode: str = Field(..., description="G-code command that was executed")
    message: str = Field(..., description="Human-readable status message")


class HomeResponse(BaseModel):
    """Response model for homing operations."""
    
    success: bool = Field(..., description="Whether homing was successful")
    message: str = Field(..., description="Status message")


class ErrorResponse(BaseModel):
    """Response model for errors."""
    
    error: bool = Field(True, description="Always true for error responses")
    error_code: str = Field(..., description="Machine-readable error code")
    message: str = Field(..., description="Human-readable error message")
    details: dict[str, Any] | None = Field(None, description="Additional error details")


class EmergencyStopResponse(BaseModel):
    """Response model for emergency stop operations."""
    
    success: bool = Field(..., description="Whether operation was successful")
    estop_active: bool = Field(..., description="Current E-stop state")
    message: str = Field(..., description="Status message")
