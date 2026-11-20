"""
Communication Protocol & JSON Message Schema definitions.
Validates commands received from Godot and serializes telemetry packets.
"""

import json
from typing import Dict, Any, Optional, Tuple


class MessageType:
    COMMAND = "command"
    JOINT_COMMAND = "joint_command"
    CLEAR_JOINT = "clear_joint"
    PUSH = "push"
    FALL_TEST = "fall_test"
    SPAWN_OBSTACLE = "spawn_obstacle"
    CLEAR_OBSTACLES = "clear_obstacles"
    SET_PID = "set_pid"
    SET_SIMULATION_SPEED = "set_simulation_speed"
    TOGGLE_AVOIDANCE = "toggle_avoidance"
    TELEMETRY = "telemetry"
    ERROR = "error"


def parse_message(raw_text: str) -> Tuple[bool, Optional[Dict[str, Any]], Optional[str]]:
    """
    Parse a JSON message string and validate basic envelope.
    Returns (success, parsed_dict, error_message).
    """
    text = raw_text.strip()
    if not text:
        return False, None, "Empty message"

    try:
        data = json.loads(text)
        if not isinstance(data, dict):
            return False, None, "Message must be a JSON object"
        if "type" not in data:
            return False, None, "Missing 'type' field in message"
        return True, data, None
    except json.JSONDecodeError as e:
        return False, None, f"JSON decode error: {e}"


def serialize_message(data: Dict[str, Any]) -> bytes:
    """Serialize dictionary to UTF-8 encoded JSON string with newline delimiter."""
    return (json.dumps(data, separators=(",", ":")) + "\n").encode("utf-8")
