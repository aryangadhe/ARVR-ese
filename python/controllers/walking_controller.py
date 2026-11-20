"""
Humanoid walking gait generator and controller.
Implements a stable alternating bipedal gait with continuous forward stance push,
swing leg ground clearance, dynamic lateral weight shifting, and kinematic foot leveling.
"""

import math
from typing import Dict, Any
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

    def __init__(self):
        self.is_walking = False
        self.step_time = 0.0
        self.step_duration = 0.50  # seconds per half-stride step
        self.speed = 0.5  # walking speed multiplier
        self.turn_rate = 0.0  # steering bias [-1.0 = left, +1.0 = right]
        self.current_step_idx = 0  # 0: Left swing / Right stance, 1: Right swing / Left stance

        # Nominal standing joint angles (radians)
        # Symmetrically positioned over foot center (+0.06m) with parallel foot soles:
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

        # Gait trajectory parameters
        self.step_amp = 0.08  # forward swing reach
        self.push_amp = 0.08  # continuous backward stance push (symmetric with swing reach)
        self.knee_pitch_amp = 0.20  # knee lift clearance
        self.arm_swing_amp = 0.15  # counterbalance arm swing
        self.lateral_roll_amp = 0.030  # weight shift roll towards stance foot

    def start_walking(self, speed: float = 0.5):
        self.is_walking = True
        self.speed = clamp(speed, 0.2, 1.2)

    def stop_walking(self):
        self.is_walking = False
        self.step_time = 0.0
        self.turn_rate = 0.0

    def set_speed(self, speed: float):
        self.speed = clamp(speed, 0.2, 1.2)

    def set_turn_rate(self, turn_rate: float):
        self.turn_rate = clamp(turn_rate, -1.0, 1.0)

    def update(self, dt: float, pitch: float = 0.0, pitch_rate: float = 0.0) -> Dict[str, Any]:
        """
        Advance gait generator and produce target joint angles.
        Applies active stance ankle pitch stabilization to keep sole flat and body upright.
        """
        if not self.is_walking:
            return {
                "active": False,
                "phase": "IDLE",
                "phase_index": -1,
                "targets": dict(self.nominal_standing),
            }

        # Adjust step progression by speed multiplier
        effective_rate = (self.speed / 0.5)
        self.step_time += dt * effective_rate

        if self.step_time >= self.step_duration:
            self.step_time = 0.0
            self.current_step_idx = 1 - self.current_step_idx

        u = clamp(self.step_time / self.step_duration, 0.0, 1.0)

        # Monotonic smooth half-cosine functions:
        # f_fwd sweeps strictly from -1 to +1 (forward swing progression)
        # f_bwd sweeps strictly from +1 to -1 (backward stance push progression)
        f_fwd = -math.cos(math.pi * u)
        f_bwd = math.cos(math.pi * u)
        lift = self.knee_pitch_amp * math.sin(math.pi * u)
        roll = self.lateral_roll_amp * math.sin(math.pi * u)

        # Steering bias from turn_rate
        left_turn_bias = -self.turn_rate * 0.10
        right_turn_bias = self.turn_rate * 0.10

        nom = self.nominal_standing
        targets = dict(nom)

        # Active stance sole pitch stabilization via ankle ground reaction
        ankle_stabilizer = 1.5 * pitch + 0.05 * pitch_rate

        if self.current_step_idx == 0:
            phase_idx = self.PHASE_LEFT_SWING if u < 0.8 else self.PHASE_WEIGHT_SHIFT_LEFT
            # Left leg: Swing (lifts foot, reaches forward)
            hip_l = nom["left_hip_pitch"] - (self.step_amp * f_fwd) + left_turn_bias
            knee_l = nom["left_knee_pitch"] + lift
            ankle_l = -hip_l - knee_l + 0.03

            # Right leg: Stance (pushes backward on ground with sole leveling)
            hip_r = nom["right_hip_pitch"] - (self.push_amp * f_bwd) + right_turn_bias
            knee_r = nom["right_knee_pitch"]
            ankle_r = nom["right_ankle_pitch"] + ankle_stabilizer

            # Torso rolls towards right support foot
            roll_l = -roll
            roll_r = -roll
        else:
            phase_idx = self.PHASE_RIGHT_SWING if u < 0.8 else self.PHASE_WEIGHT_SHIFT_RIGHT
            # Right leg: Swing (lifts foot, reaches forward)
            hip_r = nom["right_hip_pitch"] - (self.step_amp * f_fwd) + right_turn_bias
            knee_r = nom["right_knee_pitch"] + lift
            ankle_r = -hip_r - knee_r + 0.03

            # Left leg: Stance (pushes backward on ground with sole leveling)
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
            "phase": self.PHASE_NAMES[phase_idx],
            "phase_index": phase_idx,
            "progress": round(u, 3),
            "speed": self.speed,
            "turn_rate": self.turn_rate,
            "targets": targets,
        }

    def reset(self):
        self.is_walking = False
        self.step_time = 0.0
        self.turn_rate = 0.0
        self.current_step_idx = 0
