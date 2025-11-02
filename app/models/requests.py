"""
Pydantic models for API request validation.
"""
from pydantic import BaseModel, Field, field_validator


class MoveRequest(BaseModel):
    """Request model for movement commands."""
    
    x: float | None = Field(None, description="X-axis target position in mm")
    y: float | None = Field(None, description="Y-axis target position in mm")
    z: float | None = Field(None, description="Z-axis target position in mm")
    feed_rate: float = Field(1000.0, ge=1.0, le=10000.0, description="Feed rate in mm/min")
    rapid: bool = Field(False, description="Use rapid (G0) motion instead of linear (G1)")
    wait: bool = Field(True, description="Wait for motion to complete before returning")
    
    @field_validator('x', 'y', 'z')
    @classmethod
    def validate_coordinates(cls, v: float | None) -> float | None:
        """
        Validate coordinate values are within reasonable range.
        
        :param v: Coordinate value
        :type v: float | None
        :return: Validated coordinate
        :rtype: float | None
        :raises ValueError: If coordinate is out of range
        """
        if v is not None and (v < -10000 or v > 10000):
            raise ValueError("Coordinate must be between -10000 and 10000 mm")
        return v


class RelativeMoveRequest(BaseModel):
    """Request model for relative movement commands."""
    
    x: float | None = Field(None, description="X-axis displacement in mm")
    y: float | None = Field(None, description="Y-axis displacement in mm")
    z: float | None = Field(None, description="Z-axis displacement in mm")
    feed_rate: float = Field(1000.0, ge=1.0, le=10000.0, description="Feed rate in mm/min")
    rapid: bool = Field(False, description="Use rapid (G0) motion")
    wait: bool = Field(True, description="Wait for completion")


class HomeRequest(BaseModel):
    """Request model for homing operations."""
    
    wait: bool = Field(True, description="Wait for homing to complete")


class EmergencyStopRequest(BaseModel):
    """Request model for emergency stop operations."""
    
    reset: bool = Field(False, description="Reset E-stop if True, activate if False")
