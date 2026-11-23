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
            "com_ground_projection": simulation_data.get("com_ground_projection", [0.0, 0.0, 0.0]),
            "support_polygon": simulation_data.get("support_polygon", []),
            "balance_error": simulation_data.get("balance_error", 0.0),
            "average_balance_error": simulation_data.get("average_balance_error", 0.0),
            "foot_contacts": simulation_data.get("foot_contacts", {}),
            "pid_gains": simulation_data.get("pid_gains", {}),
            "walking": simulation_data.get("walking", {}),
            "obstacle_avoidance": simulation_data.get("obstacle_avoidance", {}),
            "navigation": simulation_data.get("navigation", {}),
            "sensors": simulation_data.get("sensors", {}),
            "joints": simulation_data.get("joints", {}),
            "links": simulation_data.get("links", {}),
            "obstacles": simulation_data.get("obstacles", []),
            "collision_count": simulation_data.get("collision_count", 0),
            "active_collision": simulation_data.get("active_collision", False),
            "events": simulation_data.get("events", []),
            "experiment": simulation_data.get("experiment", {}),
            "physics": simulation_data.get("physics", {}),
        }
        return payload

