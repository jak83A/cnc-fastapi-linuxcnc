# app/core/controller.py
"""
LinuxCNC controller wrapper with modular, well-documented methods.
"""
import sys
import time
from typing import Any

from app.core.exceptions import (
    MachineNotHomedException,
    EStopActiveException,
    MotionException,
    LinuxCNCConnectionException,
)


class CNCController:
    """Wrapper around LinuxCNC Python API for CNC machine control."""

    def __init__(self, linuxcnc_path: str = "/usr/lib/python3/dist-packages", poll_interval: float = 0.05) -> None:
        """
        Initialize CNC controller connection.

        :param linuxcnc_path: Path to LinuxCNC Python modules
        :type linuxcnc_path: str
        :param poll_interval: Seconds to sleep between status polls
        :type poll_interval: float
        :raises LinuxCNCConnectionException: If cannot import or connect to LinuxCNC
        """
        self.poll_interval = poll_interval

        try:
            # Try importing linuxcnc from current sys.path first (respects PYTHONPATH)
            # This allows RIP environments to work when PYTHONPATH is set
            try:
                import linuxcnc
            except ImportError:
                # Fallback to configured path if not found in PYTHONPATH
                sys.path.append(linuxcnc_path)
                import linuxcnc

            self.linuxcnc = linuxcnc

            # Log environment info for debugging (optional check)
            import os
            nml_file = os.environ.get("NMLFILE", "")
            ini_file = os.environ.get("INI_FILE_NAME", "")
            emc2_home = os.environ.get("EMC2_HOME", "")

            # These are informational - LinuxCNC may work without them explicitly set
            # if the module can find the running instance through other means
            if not nml_file:
                import warnings
                warnings.warn(
                    "NMLFILE environment variable not set. "
                    "LinuxCNC connection may fail if instance not found."
                )

            self.command = linuxcnc.command()
            self.status = linuxcnc.stat()
            self.error_channel = linuxcnc.error_channel()
        except LinuxCNCConnectionException:
            raise
        except Exception as e:
            raise LinuxCNCConnectionException(f"Failed to connect to LinuxCNC: {str(e)}")
    
    # ==================== Private Helper Methods ====================
    
    def _poll_status(self) -> None:
        """
        Update status from LinuxCNC.

        :raises LinuxCNCConnectionException: If status poll fails
        """
        max_retries = 3
        last_error = None

        for attempt in range(max_retries):
            try:
                self.status.poll()
                return
            except Exception as e:
                last_error = e
                if attempt < max_retries - 1:
                    time.sleep(self.poll_interval * (attempt + 1))
                    continue

        raise LinuxCNCConnectionException(f"Status poll failed after {max_retries} attempts: {str(last_error)}")
    
    def _drain_error_messages(self) -> list[tuple[int, str]]:
        """
        Retrieve and clear all pending error messages.
        
        :return: List of (error_kind, error_text) tuples
        :rtype: list[tuple[int, str]]
        """
        messages = []
        while True:
            msg = self.error_channel.poll()
            if not msg:
                break
            messages.append(msg)
        return messages
    
    def _wait_for_interpreter_idle(self) -> None:
        """
        Block until interpreter finishes current MDI/program.
        
        :raises LinuxCNCConnectionException: If status polling fails
        """
        while True:
            self._poll_status()
            if self.status.interp_state == self.linuxcnc.INTERP_IDLE:
                break
            time.sleep(self.poll_interval)
    
    def _ensure_machine_on(self) -> None:
        """
        Reset E-stop and turn machine on if needed.

        :raises EStopActiveException: If E-stop cannot be cleared
        """
        self._poll_status()

        if self.status.task_state == self.linuxcnc.STATE_ESTOP:
            self.command.state(self.linuxcnc.STATE_ESTOP_RESET)
            self.command.wait_complete()
            self._poll_status()

        if self.status.task_state != self.linuxcnc.STATE_ON:
            self.command.state(self.linuxcnc.STATE_ON)
            self.command.wait_complete()

    def _switch_to_mdi_mode(self) -> None:
        """
        Switch controller to MDI (Manual Data Input) mode.
        """
        self.command.mode(self.linuxcnc.MODE_MDI)
        self.command.wait_complete()
    
    def _verify_machine_homed(self) -> None:
        """
        Verify all joints are homed.

        :raises MachineNotHomedException: If any joint is not homed
        """
        self._poll_status()
        homed = getattr(self.status, "homed", None)

        # Get number of configured joints from axis_mask
        axis_mask = getattr(self.status, "axis_mask", 0)
        if axis_mask > 0:
            num_joints = bin(axis_mask).count('1')
        else:
            num_joints = 3

        if isinstance(homed, (list, tuple)) and len(homed) >= num_joints:
            # Only check configured joints, not all 16
            if not all(homed[:num_joints]):
                raise MachineNotHomedException("All axes must be homed before motion commands")
        else:
            raise MachineNotHomedException("All axes must be homed before motion commands")
    
    def _execute_mdi_command(self, gcode: str, wait: bool = True) -> None:
        """
        Execute G-code command via MDI.
        
        :param gcode: G-code command string
        :type gcode: str
        :param wait: Whether to wait for completion
        :type wait: bool
        :raises MotionException: If command execution fails
        """
        self.command.mdi(gcode)
        self.command.wait_complete()
        
        if wait:
            self._wait_for_interpreter_idle()
        
        errors = self._drain_error_messages()
        if errors:
            kind, text = errors[0]
            raise MotionException(f"G-code error [{kind}]: {text}", gcode=gcode)
    
    # ==================== Public API Methods ====================
    
    def get_current_position(self) -> dict[str, float]:
        """
        Get current machine position for all axes.
        
        :return: Dictionary with axis positions (x, y, z, etc.)
        :rtype: dict[str, float]
        """
        self._poll_status()
        position = self.status.position
        
        return {
            "x": position[0],
            "y": position[1],
            "z": position[2],
            "a": position[3] if len(position) > 3 else 0.0,
        }
    
    def get_machine_status(self) -> dict[str, Any]:
        """
        Get comprehensive machine status.
        
        :return: Dictionary with machine state information
        :rtype: dict[str, Any]
        """
        self._poll_status()
        
        return {
            "position": self.get_current_position(),
            "homed": list(getattr(self.status, "homed", [])),
            "estop_active": self.status.task_state == self.linuxcnc.STATE_ESTOP,
            "machine_on": self.status.task_state == self.linuxcnc.STATE_ON,
            "interp_state": self.status.interp_state,
            "feed_rate": self.status.current_vel * 60,  # Convert to mm/min
        }
    
    def home_all_axes(self, wait: bool = True) -> None:
        """
        Home all machine axes.

        :param wait: Whether to wait for homing to complete
        :type wait: bool
        :raises EStopActiveException: If E-stop is active
        """
        self._ensure_machine_on()

        # Switch to MANUAL mode for homing (not MDI mode!)
        self.command.mode(self.linuxcnc.MODE_MANUAL)
        self.command.wait_complete()

        self._poll_status()

        # Get actual number of configured joints from axis_mask
        # axis_mask is a bitmask where each bit represents an axis (X=1, Y=2, Z=4, etc.)
        axis_mask = getattr(self.status, "axis_mask", 0)
        if axis_mask > 0:
            # Count the number of set bits
            num_joints = bin(axis_mask).count('1')
        else:
            # Fallback: use a reasonable default for typical 3-axis machine
            # Don't use len(status.joints) as it's always 16 (fixed buffer size)
            num_joints = 3

        for joint_index in range(num_joints):
            self.command.home(joint_index)

        if wait:
            self._wait_for_homing_complete(num_joints)

    def _wait_for_homing_complete(self, num_joints: int = 0) -> None:
        """
        Wait until all configured joints are homed.

        :param num_joints: Number of joints to wait for (0 = all in homed list)
        :type num_joints: int
        """
        while True:
            self._poll_status()
            homed = getattr(self.status, "homed", [])
            if isinstance(homed, (list, tuple)) and homed:
                # Only check the configured number of joints
                if num_joints > 0:
                    joints_to_check = homed[:num_joints]
                else:
                    joints_to_check = homed
                if all(joints_to_check):
                    break
            time.sleep(self.poll_interval)
    
    def move_absolute(
        self,
        x: float | None = None,
        y: float | None = None,
        z: float | None = None,
        feed_rate: float = 1000.0,
        rapid: bool = False,
        wait: bool = True,
    ) -> str:
        """
        Move to absolute coordinates.
        
        :param x: Target X coordinate in mm (None to skip)
        :type x: float | None
        :param y: Target Y coordinate in mm (None to skip)
        :type y: float | None
        :param z: Target Z coordinate in mm (None to skip)
        :type z: float | None
        :param feed_rate: Feed rate in mm/min (ignored if rapid=True)
        :type feed_rate: float
        :param rapid: Use rapid (G0) instead of linear (G1) motion
        :type rapid: bool
        :param wait: Wait for motion to complete
        :type wait: bool
        :return: Executed G-code command
        :rtype: str
        :raises MachineNotHomedException: If machine is not homed
        :raises MotionException: If motion command fails
        """
        return self._execute_move(
            x=x, y=y, z=z,
            feed_rate=feed_rate,
            rapid=rapid,
            absolute=True,
            wait=wait
        )
    
    def move_relative(
        self,
        x: float | None = None,
        y: float | None = None,
        z: float | None = None,
        feed_rate: float = 1000.0,
        rapid: bool = False,
        wait: bool = True,
    ) -> str:
        """
        Move relative to current position.
        
        :param x: X displacement in mm (None to skip)
        :type x: float | None
        :param y: Y displacement in mm (None to skip)
        :type y: float | None
        :param z: Z displacement in mm (None to skip)
        :type z: float | None
        :param feed_rate: Feed rate in mm/min (ignored if rapid=True)
        :type feed_rate: float
        :param rapid: Use rapid (G0) instead of linear (G1) motion
        :type rapid: bool
        :param wait: Wait for motion to complete
        :type wait: bool
        :return: Executed G-code command
        :rtype: str
        :raises MachineNotHomedException: If machine is not homed
        :raises MotionException: If motion command fails
        """
        return self._execute_move(
            x=x, y=y, z=z,
            feed_rate=feed_rate,
            rapid=rapid,
            absolute=False,
            wait=wait
        )
    
    def _execute_move(
        self,
        x: float | None,
        y: float | None,
        z: float | None,
        feed_rate: float,
        rapid: bool,
        absolute: bool,
        wait: bool,
    ) -> str:
        """
        Internal method to execute motion commands.
        
        :param x: X coordinate/displacement
        :param y: Y coordinate/displacement
        :param z: Z coordinate/displacement
        :param feed_rate: Feed rate in mm/min
        :param rapid: Use rapid motion
        :param absolute: Absolute (True) or relative (False) positioning
        :param wait: Wait for completion
        :return: Executed G-code command
        :rtype: str
        """
        self._drain_error_messages()
        self._ensure_machine_on()
        self._verify_machine_homed()
        self._switch_to_mdi_mode()
        
        gcode = self._build_gcode_command(x, y, z, feed_rate, rapid, absolute)
        self._execute_mdi_command(gcode, wait=wait)
        
        return gcode
    
    def _build_gcode_command(
        self,
        x: float | None,
        y: float | None,
        z: float | None,
        feed_rate: float,
        rapid: bool,
        absolute: bool,
    ) -> str:
        """
        Build G-code command from parameters.
        
        :param x: X coordinate/displacement
        :param y: Y coordinate/displacement
        :param z: Z coordinate/displacement
        :param feed_rate: Feed rate
        :param rapid: Use rapid motion
        :param absolute: Absolute positioning
        :return: G-code command string
        :rtype: str
        """
        words = ["G21"]  # Metric units
        words.append("G90" if absolute else "G91")
        words.append("G0" if rapid else "G1")
        
        if x is not None:
            words.append(f"X{float(x):.4f}")
        if y is not None:
            words.append(f"Y{float(y):.4f}")
        if z is not None:
            words.append(f"Z{float(z):.4f}")
        
        if not rapid:
            words.append(f"F{float(feed_rate):.4f}")
        
        return " ".join(words)
    
    def emergency_stop(self) -> None:
        """
        Activate emergency stop immediately.
        """
        self.command.state(self.linuxcnc.STATE_ESTOP)
        self.command.wait_complete()
    
    def reset_emergency_stop(self) -> None:
        """
        Reset emergency stop state.

        :raises EStopActiveException: If E-stop cannot be reset
        """
        self.command.state(self.linuxcnc.STATE_ESTOP_RESET)
        self.command.wait_complete()

    def machine_on(self) -> None:
        """
        Turn machine on (enable drives).

        :raises EStopActiveException: If E-stop is still active
        """
        self._poll_status()
        if self.status.task_state == self.linuxcnc.STATE_ESTOP:
            raise EStopActiveException("Cannot turn machine on while E-stop is active")
        self.command.state(self.linuxcnc.STATE_ON)
        self.command.wait_complete()

    def machine_off(self) -> None:
        """
        Turn machine off (disable drives).
        """
        self.command.state(self.linuxcnc.STATE_OFF)
        self.command.wait_complete()
