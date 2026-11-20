"""
Obstacle detection and reactive steering avoidance controller.
Evaluates distance sensor rays and calculates steering turn bias and speed modulation.
"""

from typing import Dict, Any


class ObstacleAvoidanceController:
    # Action modes
    ACTION_CLEAR = "CLEAR"
    ACTION_AVOID_LEFT = "AVOIDING_LEFT"
    ACTION_AVOID_RIGHT = "AVOIDING_RIGHT"
    ACTION_STOP = "EMERGENCY_STOP"

    def __init__(
        self,
        stop_threshold: float = 0.70,
        warning_threshold: float = 1.40,
    ):
        self.enabled = True
        self.stop_threshold = float(stop_threshold)
        self.warning_threshold = float(warning_threshold)
        self.current_action = self.ACTION_CLEAR
        self.turn_rate = 0.0
        self.speed_factor = 1.0

    def evaluate(self, distance_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Evaluate distance sensor readings and determine steering and speed modulation.
        """
        if not self.enabled:
            return {
                "enabled": False,
                "action": self.ACTION_CLEAR,
                "turn_rate": 0.0,
                "speed_factor": 1.0,
                "reason": "Avoidance disabled",
            }

        front = distance_data.get("front_distance", 5.0)
        left = distance_data.get("left_distance", 5.0)
        right = distance_data.get("right_distance", 5.0)

        # Decision logic from specification:
        if front < self.stop_threshold and left < self.stop_threshold and right < self.stop_threshold:
            # Trapped or blocked in all directions
            self.current_action = self.ACTION_STOP
            self.turn_rate = 0.0
            self.speed_factor = 0.0
            reason = "Trapped: all paths blocked"
        elif front < self.warning_threshold:
            # Front is obstructed: slow down and steer toward clearer side
            self.speed_factor = max(0.2, (front - self.stop_threshold) / (self.warning_threshold - self.stop_threshold))

            if left > right and left > self.stop_threshold:
                self.current_action = self.ACTION_AVOID_LEFT
                # Turn left: negative turn rate
                self.turn_rate = -0.75
                reason = f"Obstacle ahead ({front}m): steering left (left: {left}m > right: {right}m)"
            elif right > left and right > self.stop_threshold:
                self.current_action = self.ACTION_AVOID_RIGHT
                # Turn right: positive turn rate
                self.turn_rate = 0.75
                reason = f"Obstacle ahead ({front}m): steering right (right: {right}m > left: {left}m)"
            else:
                self.current_action = self.ACTION_STOP
                self.turn_rate = 0.0
                self.speed_factor = 0.0
                reason = "Front obstructed, no clear alternate path"
        else:
            # Clear path ahead
            self.current_action = self.ACTION_CLEAR
            self.turn_rate = 0.0
            self.speed_factor = 1.0
            reason = "Path clear"

        return {
            "enabled": self.enabled,
            "action": self.current_action,
            "turn_rate": self.turn_rate,
            "speed_factor": round(self.speed_factor, 2),
            "reason": reason,
        }

    def reset(self):
        self.current_action = self.ACTION_CLEAR
        self.turn_rate = 0.0
        self.speed_factor = 1.0

