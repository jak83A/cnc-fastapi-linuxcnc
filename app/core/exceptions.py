# app/core/exceptions.py
"""
Custom exception classes for CNC API.
"""


class CNCException(Exception):
    """Base exception for all CNC-related errors."""
    
    def __init__(self, message: str, error_code: str | None = None) -> None:
        """
        Initialize CNC exception.
        
        :param message: Human-readable error message
        :type message: str
        :param error_code: Optional error code for client handling
        :type error_code: str | None
        """
        self.message = message
        self.error_code = error_code
        super().__init__(self.message)


class MachineNotHomedException(CNCException):
    """Raised when operation requires homed machine but it's not homed."""
    
    def __init__(self, message: str = "Machine must be homed before this operation") -> None:
        """
        Initialize machine not homed exception.
        
        :param message: Error message
        :type message: str
        """
        super().__init__(message, error_code="MACHINE_NOT_HOMED")


class EStopActiveException(CNCException):
    """Raised when E-stop is active."""
    
    def __init__(self, message: str = "Emergency stop is active") -> None:
        """
        Initialize E-stop active exception.
        
        :param message: Error message
        :type message: str
        """
        super().__init__(message, error_code="ESTOP_ACTIVE")


class InvalidParameterException(CNCException):
    """Raised when invalid parameters are provided."""
    
    def __init__(self, parameter: str, reason: str) -> None:
        """
        Initialize invalid parameter exception.
        
        :param parameter: Name of the invalid parameter
        :type parameter: str
        :param reason: Reason why parameter is invalid
        :type reason: str
        """
        message = f"Invalid parameter '{parameter}': {reason}"
        super().__init__(message, error_code="INVALID_PARAMETER")


class MotionException(CNCException):
    """Raised when motion command fails."""
    
    def __init__(self, message: str, gcode: str | None = None) -> None:
        """
        Initialize motion exception.
        
        :param message: Error message
        :type message: str
        :param gcode: G-code that caused the error
        :type gcode: str | None
        """
        self.gcode = gcode
        full_message = f"{message}"
        if gcode:
            full_message += f" (G-code: {gcode})"
        super().__init__(full_message, error_code="MOTION_ERROR")


class LinuxCNCConnectionException(CNCException):
    """Raised when cannot connect to LinuxCNC."""
    
    def __init__(self, message: str = "Cannot connect to LinuxCNC") -> None:
        """
        Initialize LinuxCNC connection exception.
        
        :param message: Error message
        :type message: str
        """
        super().__init__(message, error_code="LINUXCNC_CONNECTION_ERROR")
