"""
CNC service layer containing business logic.
"""
from typing import Any
from app.core.controller import CNCController
from app.config.settings import settings


class CNCService:
    """Service class for CNC operations with business logic."""
    
    def __init__(self) -> None:
        """
        Initialize CNC service with controller.
        """
        self._controller = CNCController(
            linuxcnc_path=settings.linuxcnc_path,
            poll_interval=settings.poll_interval
        )
    
    def get_position(self) -> dict[str, float]:
        """
        Get current machine position.
        
        :return: Current position for all axes
        :rtype: dict[str, float]
        """
        return self._controller.get_current_position()
    
    def get_status(self) -> dict[str, Any]:
        """
        Get comprehensive machine status.
        
        :return: Machine status information
        :rtype: dict[str, Any]
        """
        return self._controller.get_machine_status()
    
    def execute_absolute_move(
        self,
        x: float | None = None,
        y: float | None = None,
        z: float | None = None,
        feed_rate: float | None = None,
        rapid: bool = False,
        wait: bool = True,
    ) -> dict[str, Any]:
        """
        Execute absolute position move with business logic.
        
        :param x: Target X coordinate in mm
        :type x: float | None
        :param y: Target Y coordinate in mm
        :type y: float | None
        :param z: Target Z coordinate in mm
        :type z: float | None
        :param feed_rate: Feed rate in mm/min
        :type feed_rate: float | None
        :param rapid: Use rapid motion
        :type rapid: bool
        :param wait: Wait for completion
        :type wait: bool
        :return: Move result with success status and G-code
        :rtype: dict[str, Any]
        """
        if feed_rate is None:
            feed_rate = settings.default_feed_rate
        
        gcode = self._controller.move_absolute(
            x=x, y=y, z=z,
            feed_rate=feed_rate,
            rapid=rapid,
            wait=wait
        )
        
        return {
            "success": True,
            "gcode": gcode,
            "message": "Move executed successfully"
        }
    
    def execute_relative_move(
        self,
        x: float | None = None,
        y: float | None = None,
        z: float | None = None,
        feed_rate: float | None = None,
        rapid: bool = False,
        wait: bool = True,
    ) -> dict[str, Any]:
        """
        Execute relative position move with business logic.
        
        :param x: X displacement in mm
        :type x: float | None
        :param y: Y displacement in mm
        :type y: float | None
        :param z: Z displacement in mm
        :type z: float | None
        :param feed_rate: Feed rate in mm/min
        :type feed_rate: float | None
        :param rapid: Use rapid motion
        :type rapid: bool
        :param wait: Wait for completion
        :type wait: bool
        :return: Move result with success status and G-code
        :rtype: dict[str, Any]
        """
        if feed_rate is None:
            feed_rate = settings.default_feed_rate
        
        gcode = self._controller.move_relative(
            x=x, y=y, z=z,
            feed_rate=feed_rate,
            rapid=rapid,
            wait=wait
        )
        
        return {
            "success": True,
            "gcode": gcode,
            "message": "Relative move executed successfully"
        }
    
    def home_machine(self, wait: bool = True) -> dict[str, Any]:
        """
        Home all machine axes.
        
        :param wait: Wait for homing to complete
        :type wait: bool
        :return: Homing result
        :rtype: dict[str, Any]
        """
        self._controller.home_all_axes(wait=wait)
        
        return {
            "success": True,
            "message": "Machine homed successfully"
        }
    
    def trigger_emergency_stop(self) -> dict[str, Any]:
        """
        Activate emergency stop.
        
        :return: E-stop activation result
        :rtype: dict[str, Any]
        """
        self._controller.emergency_stop()
        
        return {
            "success": True,
            "estop_active": True,
            "message": "Emergency stop activated"
        }
    
    def reset_emergency_stop(self) -> dict[str, Any]:
        """
        Reset emergency stop state.

        :return: E-stop reset result
        :rtype: dict[str, Any]
        """
        self._controller.reset_emergency_stop()

        return {
            "success": True,
            "estop_active": False,
            "message": "Emergency stop reset"
        }

    def set_machine_power(self, on: bool) -> dict[str, Any]:
        """
        Turn machine on or off.

        :param on: True to turn on, False to turn off
        :type on: bool
        :return: Machine power state result
        :rtype: dict[str, Any]
        """
        if on:
            self._controller.machine_on()
            message = "Machine turned on"
        else:
            self._controller.machine_off()
            message = "Machine turned off"

        return {
            "success": True,
            "machine_on": on,
            "message": message
        }
