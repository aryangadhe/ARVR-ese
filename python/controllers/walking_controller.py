"""
Humanoid walking gait generator and controller.
Implements a stable 4-phase alternating bipedal gait with parallel stance-foot
kinematic leveling, arm swing coordination, and adjustable walking frequency.
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
        self.phase_time = 0.0
        self.cycle_time = 1.1  # seconds per full gait cycle
        self.speed = 0.4  # walking speed multiplier
        self.turn_rate = 0.0  # steering bias [-1.0 = left, +1.0 = right]

        # Nominal standing joint angles (radians)
        # Hip(-0.08) + Knee(+0.16) + Ankle(-0.08) = 0.0 -> perfectly flat foot
        self.nominal_standing = {
            "neck_pitch": 0.0,
            "left_shoulder_pitch": 0.0,
            "left_elbow_pitch": 0.35,
            "right_shoulder_pitch": 0.0,
            "right_elbow_pitch": 0.35,
            "left_hip_roll": 0.0,
            "left_hip_pitch": -0.08,
            "left_knee_pitch": 0.16,
            "left_ankle_pitch": -0.08,
            "right_hip_roll": 0.0,
            "right_hip_pitch": -0.08,
            "right_knee_pitch": 0.16,
            "right_ankle_pitch": -0.08,
        }

        # Gait trajectory parameters
        self.hip_pitch_amp = 0.16  # moderate step length for physical stability
        self.knee_pitch_amp = 0.22  # knee ground clearance
        self.arm_swing_amp = 0.22  # counterbalance arm swing
        self.lateral_roll_amp = 0.03  # weight shift roll

    def start_walking(self, speed: float = 0.4):
        self.is_walking = True
        self.speed = clamp(speed, 0.1, 1.2)

    def stop_walking(self):
        self.is_walking = False
        self.turn_rate = 0.0

    def set_speed(self, speed: float):
        self.speed = clamp(speed, 0.1, 1.2)

    def set_turn_rate(self, turn_rate: float):
        self.turn_rate = clamp(turn_rate, -1.0, 1.0)

    def update(self, dt: float) -> Dict[str, Any]:
        """
        Advance gait generator and produce target joint angles with kinematic foot leveling.
        """
        if not self.is_walking:
            return {
                "active": False,
                "phase": "IDLE",
                "phase_index": -1,
                "targets": dict(self.nominal_standing),
            }

        effective_freq = (1.0 / self.cycle_time) * self.speed
        self.phase_time += dt * effective_freq * 2.0 * math.pi
        phase_normalized = (self.phase_time % (2.0 * math.pi)) / (2.0 * math.pi)

        if phase_normalized < 0.25:
            phase_idx = self.PHASE_LEFT_SWING
        elif phase_normalized < 0.50:
            phase_idx = self.PHASE_WEIGHT_SHIFT_LEFT
        elif phase_normalized < 0.75:
            phase_idx = self.PHASE_RIGHT_SWING
        else:
            phase_idx = self.PHASE_WEIGHT_SHIFT_RIGHT

        sin_t = math.sin(self.phase_time)
        cos_t = math.cos(self.phase_time)

        # Steering bias
        left_turn_bias = -self.turn_rate * 0.12
        right_turn_bias = self.turn_rate * 0.12

        # Kinematic foot trajectory:
        # When sin_t > 0: Left leg is swing (moves forward), Right leg is stance (supports)
        # When sin_t < 0: Right leg is swing (moves forward), Left leg is stance (supports)
        if sin_t >= 0.0:
            # Left leg swing
            left_hip_p = self.nominal_standing["left_hip_pitch"] - (sin_t * self.hip_pitch_amp) + left_turn_bias
            left_knee_p = self.nominal_standing["left_knee_pitch"] + (sin_t * self.knee_pitch_amp)
            # Level foot with slight toe lift
            left_ankle_p = -left_hip_p - left_knee_p + 0.04

            # Right leg stance (supports weight and pushes backward)
            right_hip_p = self.nominal_standing["right_hip_pitch"] + (sin_t * self.hip_pitch_amp * 0.4) + right_turn_bias
            right_knee_p = self.nominal_standing["right_knee_pitch"]
            # Enforce parallel sole to ground
            right_ankle_p = -right_hip_p - right_knee_p
        else:
            # Right leg swing
            abs_sin = -sin_t
            right_hip_p = self.nominal_standing["right_hip_pitch"] - (abs_sin * self.hip_pitch_amp) + right_turn_bias
            right_knee_p = self.nominal_standing["right_knee_pitch"] + (abs_sin * self.knee_pitch_amp)
            right_ankle_p = -right_hip_p - right_knee_p + 0.04

            # Left leg stance
            left_hip_p = self.nominal_standing["left_hip_pitch"] + (abs_sin * self.hip_pitch_amp * 0.4) + left_turn_bias
            left_knee_p = self.nominal_standing["left_knee_pitch"]
            left_ankle_p = -left_hip_p - left_knee_p

        # Lateral pelvis roll for weight transfer (mirrored hips across X-axis)
        lateral_roll = cos_t * self.lateral_roll_amp
        left_hip_r = self.nominal_standing["left_hip_roll"] + lateral_roll
        right_hip_r = self.nominal_standing["right_hip_roll"] - lateral_roll

        # Counterbalance arm swing
        left_arm_p = self.nominal_standing["left_shoulder_pitch"] + (sin_t * self.arm_swing_amp)
        right_arm_p = self.nominal_standing["right_shoulder_pitch"] - (sin_t * self.arm_swing_amp)

        targets = {
            "neck_pitch": 0.0,
            "left_shoulder_pitch": left_arm_p,
            "left_elbow_pitch": 0.35 + abs(sin_t) * 0.10,
            "right_shoulder_pitch": right_arm_p,
            "right_elbow_pitch": 0.35 + abs(sin_t) * 0.10,
            "left_hip_roll": left_hip_r,
            "left_hip_pitch": left_hip_p,
            "left_knee_pitch": left_knee_p,
            "left_ankle_pitch": left_ankle_p,
            "right_hip_roll": right_hip_r,
            "right_hip_pitch": right_hip_p,
            "right_knee_pitch": right_knee_p,
            "right_ankle_pitch": right_ankle_p,
        }

        return {
            "active": True,
            "phase": self.PHASE_NAMES[phase_idx],
            "phase_index": phase_idx,
            "progress": round(phase_normalized, 3),
            "speed": self.speed,
            "turn_rate": self.turn_rate,
            "targets": targets,
        }

    def reset(self):
        self.is_walking = False
        self.phase_time = 0.0
        self.turn_rate = 0.0
