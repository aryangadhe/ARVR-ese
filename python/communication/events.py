"""
Structured Event Logging System for Robotics Simulation Platform.
Buffers timestamped, categorized events with severity levels for network broadcasting.
"""

import time
from typing import Dict, Any, List


class EventLogger:
    SEVERITY_INFO = "INFO"
    SEVERITY_WARNING = "WARNING"
    SEVERITY_CRITICAL = "CRITICAL"

    def __init__(self, max_history: int = 120):
        self.max_history = max_history
        self.events: List[Dict[str, Any]] = []
        self.new_events: List[Dict[str, Any]] = []
        self.start_wall_time = time.time()

    def log(self, category: str, message: str, severity: str = SEVERITY_INFO) -> Dict[str, Any]:
        """Record an event with formatted timestamp."""
        sim_time = round(time.time() - self.start_wall_time, 2)
        mins = int(sim_time // 60)
        secs = sim_time % 60
        time_str = f"{mins:02d}:{secs:05.2f}"

        entry = {
            "timestamp": time_str,
            "sim_seconds": sim_time,
            "category": category,
            "message": message,
            "severity": severity,
        }

        self.events.append(entry)
        self.new_events.append(entry)

        if len(self.events) > self.max_history:
            self.events.pop(0)

        # Print to backend console for developer visibility
        prefix = f"[{category}]"
        print(f"[{time_str}] {prefix:<14} {message}")
        return entry

    def get_recent(self, count: int = 25) -> List[Dict[str, Any]]:
        """Return the most recent N events."""
        return list(self.events[-count:])

    def drain_new(self) -> List[Dict[str, Any]]:
        """Return and clear newly generated events since last call."""
        out = list(self.new_events)
        self.new_events.clear()
        return out

    def clear(self):
        """Clear all event history."""
        self.events.clear()
        self.new_events.clear()
