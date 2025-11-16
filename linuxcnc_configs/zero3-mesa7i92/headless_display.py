#!/usr/bin/env python3
"""
Headless display program for LinuxCNC.
This script stays running indefinitely to satisfy LinuxCNC's requirement
for a DISPLAY program, but does nothing (no GUI).
"""
import signal
import sys
import time


def signal_handler(sig, frame):
    """Handle shutdown signals gracefully."""
    sys.exit(0)


if __name__ == "__main__":
    # Register signal handlers for clean shutdown
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    # Just sleep forever - LinuxCNC will kill us when it shuts down
    while True:
        time.sleep(86400)  # Sleep for a day
