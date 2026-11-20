"""
Obstacle detection and reactive steering avoidance controller.
Evaluates distance sensor rays and calculates steering turn bias and speed modulation.
Tracks detection statistics and provides multi-level status reporting.
"""

from typing import Dict, Any


class ObstacleAvoidanceController:
    # Action modes
    ACTION_CLEAR = "CLEAR"
    ACTION_AVOID_LEFT = "AVOIDING_LEFT"
    ACTION_AVOID_RIGHT = "AVOIDING_RIGHT"
    ACTION_STOP = "EMERGENCY_STOP"

    # Status levels
    STATUS_CLEAR = "CLEAR"
    STATUS_WARNING = "WARNING"
    STATUS_DETECTED = "OBSTACLE_DETECTED"

    def __init__(
        self,
        stop_threshold: float = 0.70,
        warning_threshold: float = 1.40,
    ):
        self.enabled = True
        self.stop_threshold = float(stop_threshold)
        self.warning_threshold = float(warning_threshold)
        self.current_action = self.ACTION_CLEAR
        self.status_level = self.STATUS_CLEAR
        self.turn_rate = 0.0
        self.speed_factor = 1.0
        self.detection_count = 0
        self.last_detected = False

    def set_thresholds(self, stop_thresh: float, warn_thresh: float):
        self.stop_threshold = max(0.3, float(stop_thresh))
        self.warning_threshold = max(self.stop_threshold + 0.2, float(warn_thresh))

    def evaluate(self, distance_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Evaluate distance sensor readings and determine steering and speed modulation.
        """
        if not self.enabled:
            return {
                "enabled": False,
                "action": self.ACTION_CLEAR,
                "status_level": self.STATUS_CLEAR,
                "turn_rate": 0.0,
                "speed_factor": 1.0,
                "reason": "Avoidance disabled (Manual Mode)",
                "detection_count": self.detection_count,
            }

        front = distance_data.get("front_distance", 5.0)
        left = distance_data.get("left_distance", 5.0)
        right = distance_data.get("right_distance", 5.0)
        min_dist = min(front, left, right)

        # Count obstacle detection instances
        is_detecting = min_dist < self.warning_threshold
        if is_detecting and not self.last_detected:
            self.detection_count += 1
        self.last_detected = is_detecting

        # Decision logic:
        if front < self.stop_threshold and left < self.stop_threshold and right < self.stop_threshold:
            # Trapped or blocked in all directions
            self.current_action = self.ACTION_STOP
            self.status_level = self.STATUS_DETECTED
            self.turn_rate = 0.0
            self.speed_factor = 0.0
            reason = f"Trapped: all paths blocked (<{self.stop_threshold:.1f}m)"
        elif front < self.stop_threshold:
            # Immediate obstacle in front: sharp evasive turn
            self.status_level = self.STATUS_DETECTED
            self.speed_factor = 0.25
            if left >= right:
                self.current_action = self.ACTION_AVOID_LEFT
                self.turn_rate = -0.85
                reason = f"Obstacle close ahead ({front:.2f}m): sharp left turn"
            else:
                self.current_action = self.ACTION_AVOID_RIGHT
                self.turn_rate = 0.85
                reason = f"Obstacle close ahead ({front:.2f}m): sharp right turn"
        elif front < self.warning_threshold:
            # Front obstructed at warning distance: slow down and steer toward clearer side
            self.status_level = self.STATUS_WARNING
            ratio = (front - self.stop_threshold) / max(0.1, (self.warning_threshold - self.stop_threshold))
            self.speed_factor = max(0.35, min(1.0, ratio))

            if left > right and left > self.stop_threshold:
                self.current_action = self.ACTION_AVOID_LEFT
                self.turn_rate = -0.75
                reason = f"Obstacle ahead ({front:.2f}m): steering left (L: {left:.2f}m > R: {right:.2f}m)"
            elif right > left and right > self.stop_threshold:
                self.current_action = self.ACTION_AVOID_RIGHT
                self.turn_rate = 0.75
                reason = f"Obstacle ahead ({front:.2f}m): steering right (R: {right:.2f}m > L: {left:.2f}m)"
            else:
                self.current_action = self.ACTION_STOP
                self.turn_rate = 0.0
                self.speed_factor = 0.0
                reason = "Front obstructed, no clear alternate path"
        else:
            # Path clear
            self.current_action = self.ACTION_CLEAR
            self.status_level = self.STATUS_CLEAR
            self.turn_rate = 0.0
            self.speed_factor = 1.0
            reason = "Path clear"

        return {
            "enabled": self.enabled,
            "action": self.current_action,
            "status_level": self.status_level,
            "turn_rate": self.turn_rate,
            "speed_factor": round(self.speed_factor, 2),
            "reason": reason,
            "detection_count": self.detection_count,
            "min_distance": round(min_dist, 3),
            "front_distance": round(front, 3),
            "left_distance": round(left, 3),
            "right_distance": round(right, 3),
        }

    def reset(self):
        self.current_action = self.ACTION_CLEAR
        self.status_level = self.STATUS_CLEAR
        self.turn_rate = 0.0
        self.speed_factor = 1.0
        self.last_detected = False
        self.detection_count = 0
