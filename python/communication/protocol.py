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
    SET_DIRECTION = "set_direction"
    SET_GAIT_PARAMS = "set_gait_params"
    START_EXPERIMENT = "start_experiment"
    STOP_EXPERIMENT = "stop_experiment"
    RESET_EXPERIMENT = "reset_experiment"
    EXPORT_CSV = "export_csv"
    SET_SENSOR_RANGE = "set_sensor_range"
    SET_GRAVITY = "set_gravity"
    SET_TIME_STEP = "set_time_step"
    NAVIGATE_TO_GOAL = "navigate_to_goal"
    CANCEL_NAVIGATION = "cancel_navigation"
    CLEAR_EVENTS = "clear_events"
    TELEMETRY = "telemetry"
    ERROR = "error"


def parse_message(raw_text: str) -> Tuple[bool, Optional[Dict[str, Any]], Optional[str]]:
    """
    Parse a JSON message string and validate basic envelope.
    Returns (success, parsed_dict, error_message).
    """
    text = raw_text.strip("\x00\r\n\t ")
    if not text:
        return False, None, None

    # Strip any leading binary/control characters before '{'
    brace_idx = text.find("{")
    if brace_idx == -1:
        return False, None, None
    if brace_idx > 0:
        text = text[brace_idx:]

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

