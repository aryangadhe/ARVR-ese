"""
Advanced Humanoid Walking Controller.
Implements multi-directional bipedal walking (Forward, Backward, Turn Left, Turn Right),
adjustable stride length and step frequency, active stance ankle ground stabilization,
and real-time odometry metrics tracking.
"""

import math
from typing import Dict, Any, Optional
from python.utils.math_utils import clamp


class WalkingController:
    # Walking phases
    PHASE_LEFT_SWING = 0
    PHASE_WEIGHT_SHIFT_LEFT = 1
    PHASE_RIGHT_SWING = 2
    PHASE_WEIGHT_SHIFT_RIGHT = 3

    PHASE_NAMES = [
        "LEFT_SWING",
        "WEIGHT_SHIFT_LEFT",
        "RIGHT_SWING",
        "WEIGHT_SHIFT_RIGHT",
    ]

    # Directions
    DIR_FORWARD = "FORWARD"
    DIR_BACKWARD = "BACKWARD"
    DIR_TURN_LEFT = "TURN_LEFT"
    DIR_TURN_RIGHT = "TURN_RIGHT"

    def __init__(self):
        self.is_walking = False
        self.direction = self.DIR_FORWARD
        self.step_time = 0.0
        self.step_duration = 0.50  # seconds per half-stride step (frequency = 1/duration)
        self.speed = 0.4  # walking speed multiplier
        self.turn_rate = 0.0  # steering bias [-1.0 = left, +1.0 = right]
        self.current_step_idx = 0  # 0: Left swing / Right stance, 1: Right swing / Left stance

        # Nominal standing joint angles (radians)
        # Symmetrically positioned over foot center with flat soles:
        # Hip(-0.05) + Knee(+0.10) + Ankle(-0.05) = 0.0 -> perfectly flat foot
        self.nominal_standing = {
            "neck_pitch": 0.0,
            "left_shoulder_pitch": 0.0,
            "left_elbow_pitch": 0.0,
            "right_shoulder_pitch": 0.0,
            "right_elbow_pitch": 0.0,
            "left_hip_roll": 0.0,
            "left_hip_pitch": -0.05,
            "left_knee_pitch": 0.10,
            "left_ankle_pitch": -0.05,
            "right_hip_roll": 0.0,
            "right_hip_pitch": -0.05,
            "right_knee_pitch": 0.10,
            "right_ankle_pitch": -0.05,
        }

        # Gait trajectory parameters (adjustable)
        self.step_amp = 0.08  # forward swing reach (step length)
        self.push_amp = 0.08  # stance push propulsion (symmetric with step length)
        self.knee_pitch_amp = 0.20  # knee lift clearance
        self.arm_swing_amp = 0.15  # counterbalance arm swing
        self.lateral_roll_amp = 0.030  # weight shift roll towards stance foot

        # Odometry tracking
        self.walking_distance = 0.0
        self.prev_pos_x: Optional[float] = None
        self.instantaneous_speed = 0.0
        self.support_leg = "DOUBLE"

    @property
    def step_length(self) -> float:
        return self.step_amp

    def start_walking(self, speed: float = 0.4, direction: str = "FORWARD"):
        self.is_walking = True
        self.speed = clamp(speed, 0.2, 1.5)
        self.set_direction(direction)

    def stop_walking(self):
        self.is_walking = False
        self.step_time = 0.0
        self.turn_rate = 0.0
        self.instantaneous_speed = 0.0
        self.support_leg = "DOUBLE"

    def set_speed(self, speed: float):
        self.speed = clamp(speed, 0.2, 1.5)

    def set_direction(self, direction: str):
        dir_upper = direction.upper()
        if dir_upper in (self.DIR_FORWARD, "FWD", "FORWARD"):
            self.direction = self.DIR_FORWARD
            self.turn_rate = 0.0
        elif dir_upper in (self.DIR_BACKWARD, "BWD", "BACKWARD"):
            self.direction = self.DIR_BACKWARD
            self.turn_rate = 0.0
        elif dir_upper in (self.DIR_TURN_LEFT, "LEFT", "TURN_LEFT"):
            self.direction = self.DIR_TURN_LEFT
            self.turn_rate = -0.75
        elif dir_upper in (self.DIR_TURN_RIGHT, "RIGHT", "TURN_RIGHT"):
            self.direction = self.DIR_TURN_RIGHT
            self.turn_rate = 0.75

    def set_turn_rate(self, turn_rate: float):
        self.turn_rate = clamp(turn_rate, -1.0, 1.0)
        if abs(self.turn_rate) > 0.3:
            self.direction = self.DIR_TURN_LEFT if self.turn_rate < 0 else self.DIR_TURN_RIGHT
        elif self.direction in (self.DIR_TURN_LEFT, self.DIR_TURN_RIGHT):
            self.direction = self.DIR_FORWARD

    def set_step_length(self, amp: float):
        self.step_amp = clamp(amp, 0.04, 0.12)
        self.push_amp = self.step_amp

    def set_step_duration(self, duration: float):
        self.step_duration = clamp(duration, 0.30, 0.80)

    def update_odometry(self, current_pos_x: float, dt: float):
        """Update integrated walking distance from physical base movement."""
        if self.prev_pos_x is not None and self.is_walking and dt > 1e-6:
            dx = current_pos_x - self.prev_pos_x
            # Accumulate progress in walking direction
            if self.direction == self.DIR_FORWARD:
                if dx > 0:
                    self.walking_distance += dx
            elif self.direction == self.DIR_BACKWARD:
                if dx < 0:
                    self.walking_distance += abs(dx)
            else:
                self.walking_distance += abs(dx)
            self.instantaneous_speed = abs(dx) / dt
        self.prev_pos_x = current_pos_x

    def update(
        self,
        dt: float,
        pitch: float = 0.0,
        pitch_rate: float = 0.0,
    ) -> Dict[str, Any]:
        """
        Advance gait generator and produce target joint angles.
        Applies active stance ankle pitch stabilization to keep sole flat and body upright.
        """
        if not self.is_walking:
            self.support_leg = "DOUBLE"
            return {
                "active": False,
                "direction": "IDLE",
                "phase": "IDLE",
                "phase_index": -1,
                "support_leg": "BOTH",
                "walking_distance": round(self.walking_distance, 3),
                "speed": self.speed,
                "targets": dict(self.nominal_standing),
            }

        # Adjust step progression by speed multiplier
        effective_rate = (self.speed / 0.4)
        self.step_time += dt * effective_rate

        if self.step_time >= self.step_duration:
            self.step_time = 0.0
            self.current_step_idx = 1 - self.current_step_idx

        u = clamp(self.step_time / self.step_duration, 0.0, 1.0)

        # Monotonic smooth half-cosine functions:
        # Forward: swing sweeps -1 to +1 (reaches forward), stance sweeps +1 to -1 (pushes backward)
        # Backward: reversed sign
        dir_sign = -1.0 if self.direction == self.DIR_BACKWARD else 1.0

        f_fwd = -math.cos(math.pi * u) * dir_sign
        f_bwd = math.cos(math.pi * u) * dir_sign
        lift = self.knee_pitch_amp * math.sin(math.pi * u)
        roll = self.lateral_roll_amp * math.sin(math.pi * u)

        # Steering bias from turn_rate
        left_turn_bias = -self.turn_rate * 0.10
        right_turn_bias = self.turn_rate * 0.10

        nom = self.nominal_standing
        targets = dict(nom)

        # Active stance sole pitch stabilization via ankle ground reaction
        ankle_stabilizer = 1.5 * pitch + 0.05 * pitch_rate

        self.support_leg = "RIGHT" if self.current_step_idx == 0 else "LEFT"
        support_leg = self.support_leg

        if self.current_step_idx == 0:
            phase_idx = self.PHASE_LEFT_SWING if u < 0.8 else self.PHASE_WEIGHT_SHIFT_LEFT
            # Left leg: Swing (lifts foot, reaches forward/backward)
            hip_l = nom["left_hip_pitch"] - (self.step_amp * f_fwd) + left_turn_bias
            knee_l = nom["left_knee_pitch"] + lift
            ankle_l = -hip_l - knee_l + 0.03

            # Right leg: Stance (pushes on ground with sole leveling)
            hip_r = nom["right_hip_pitch"] - (self.push_amp * f_bwd) + right_turn_bias
            knee_r = nom["right_knee_pitch"]
            ankle_r = nom["right_ankle_pitch"] + ankle_stabilizer

            # Torso rolls towards right support foot
            roll_l = -roll
            roll_r = -roll
        else:
            phase_idx = self.PHASE_RIGHT_SWING if u < 0.8 else self.PHASE_WEIGHT_SHIFT_RIGHT
            # Right leg: Swing (lifts foot, reaches forward/backward)
            hip_r = nom["right_hip_pitch"] - (self.step_amp * f_fwd) + right_turn_bias
            knee_r = nom["right_knee_pitch"] + lift
            ankle_r = -hip_r - knee_r + 0.03

            # Left leg: Stance (pushes on ground with sole leveling)
            hip_l = nom["left_hip_pitch"] - (self.push_amp * f_bwd) + left_turn_bias
            knee_l = nom["left_knee_pitch"]
            ankle_l = nom["left_ankle_pitch"] + ankle_stabilizer

            # Torso rolls towards left support foot
            roll_l = roll
            roll_r = roll

        targets["left_hip_pitch"] = hip_l
        targets["left_knee_pitch"] = knee_l
        targets["left_ankle_pitch"] = ankle_l
        targets["right_hip_pitch"] = hip_r
        targets["right_knee_pitch"] = knee_r
        targets["right_ankle_pitch"] = ankle_r

        targets["left_hip_roll"] = roll_l
        targets["right_hip_roll"] = roll_r

        # Counterbalance arm swing
        targets["left_shoulder_pitch"] = -(hip_l - nom["left_hip_pitch"]) * 0.7
        targets["right_shoulder_pitch"] = -(hip_r - nom["right_hip_pitch"]) * 0.7

        return {
            "active": True,
            "direction": self.direction,
            "phase": self.PHASE_NAMES[phase_idx],
            "phase_index": phase_idx,
            "support_leg": support_leg,
            "progress": round(u, 3),
            "speed": self.speed,
            "turn_rate": self.turn_rate,
            "step_length": round(self.step_amp, 3),
            "step_duration": round(self.step_duration, 2),
            "step_frequency": round(1.0 / self.step_duration, 2),
            "walking_distance": round(self.walking_distance, 3),
            "instantaneous_speed": round(self.instantaneous_speed, 3),
            "targets": targets,
        }

    def reset(self):
        self.is_walking = False
        self.direction = self.DIR_FORWARD
        self.step_time = 0.0
        self.turn_rate = 0.0
        self.current_step_idx = 0
        self.prev_pos_x = None
        self.instantaneous_speed = 0.0
        self.walking_distance = 0.0
