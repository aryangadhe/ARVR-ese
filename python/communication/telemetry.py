"""
Telemetry formatting and compression module.
Prepares simulation metrics for network transmission to the Godot frontend.
"""

import time
from typing import Dict, Any
from python.communication.protocol import MessageType


class TelemetryBuilder:
    @staticmethod
    def build(simulation_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Wrap raw simulation state into standardized telemetry packet with timestamp.
        """
        payload = {
            "type": MessageType.TELEMETRY,
            "timestamp": round(time.time(), 3),
            "state": simulation_data.get("state", "UNKNOWN"),
            "fall_count": simulation_data.get("fall_count", 0),
            "balance": simulation_data.get("balance", "UNKNOWN"),
            "roll": simulation_data.get("roll", 0.0),
            "pitch": simulation_data.get("pitch", 0.0),
            "yaw": simulation_data.get("yaw", 0.0),
            "position": simulation_data.get("position", [0.0, 0.0, 0.0]),
            "linear_velocity": simulation_data.get("linear_velocity", [0.0, 0.0, 0.0]),
            "center_of_mass": simulation_data.get("center_of_mass", [0.0, 0.0, 0.0]),
            "walking": simulation_data.get("walking", {}),
            "obstacle_avoidance": simulation_data.get("obstacle_avoidance", {}),
            "sensors": simulation_data.get("sensors", {}),
            "joints": simulation_data.get("joints", {}),
            "links": simulation_data.get("links", {}),
            "obstacles": simulation_data.get("obstacles", []),
        }
        return payload
