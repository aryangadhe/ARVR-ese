"""
Humanoid walking gait generator and controller.
Implements a 4-phase alternating bipedal gait with arm swing coordination,
adjustable walking frequency/speed, and turning rate bias for obstacle steering.
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
        self.cycle_time = 1.0  # seconds per full gait cycle at nominal speed
        self.speed = 0.5  # walking speed multiplier [0.1 to 1.5]
        self.turn_rate = 0.0  # steering bias [-1.0 = full left, +1.0 = full right]

        # Nominal standing joint angles (radians)
        self.nominal_standing = {
            "neck_pitch": 0.0,
            "left_shoulder_pitch": 0.05,
            "left_elbow_pitch": 0.35,
            "right_shoulder_pitch": 0.05,
            "right_elbow_pitch": 0.35,
            "left_hip_roll": 0.0,
            "left_hip_pitch": -0.12,
            "left_knee_pitch": 0.24,
            "left_ankle_pitch": -0.12,
            "right_hip_roll": 0.0,
            "right_hip_pitch": -0.12,
            "right_knee_pitch": 0.24,
            "right_ankle_pitch": -0.12,
        }

        # Gait trajectory amplitudes
        self.hip_pitch_amp = 0.28  # forward/backward leg swing
        self.knee_pitch_amp = 0.36  # knee clearance lift
        self.ankle_pitch_amp = 0.16  # foot clearance
        self.arm_swing_amp = 0.30  # counterbalance arm swing
        self.lateral_roll_amp = 0.06  # weight shift roll

    def start_walking(self, speed: float = 0.5):
        self.is_walking = True
        self.speed = clamp(speed, 0.1, 1.5)

    def stop_walking(self):
        self.is_walking = False
        self.turn_rate = 0.0

    def set_speed(self, speed: float):
        self.speed = clamp(speed, 0.1, 1.5)

    def set_turn_rate(self, turn_rate: float):
        """Set steering bias [-1.0 to 1.0]. Negative = turn left, positive = turn right."""
        self.turn_rate = clamp(turn_rate, -1.0, 1.0)

    def update(self, dt: float) -> Dict[str, Any]:
        """
        Advance gait generator and produce target joint angles for the current time step.
        """
        if not self.is_walking:
            # Gradually blend back to nominal standing
            return {
                "active": False,
                "phase": "IDLE",
                "phase_index": -1,
                "targets": dict(self.nominal_standing),
            }

        # Advance phase timer proportional to speed
        effective_freq = (1.0 / self.cycle_time) * self.speed
        self.phase_time += dt * effective_freq * 2.0 * math.pi
        phase_normalized = (self.phase_time % (2.0 * math.pi)) / (2.0 * math.pi)

        # Determine discrete phase for telemetry
        if phase_normalized < 0.25:
            phase_idx = self.PHASE_LEFT_SWING
        elif phase_normalized < 0.50:
            phase_idx = self.PHASE_WEIGHT_SHIFT_LEFT
        elif phase_normalized < 0.75:
            phase_idx = self.PHASE_RIGHT_SWING
        else:
            phase_idx = self.PHASE_WEIGHT_SHIFT_RIGHT

        # Continuous cyclic harmonic functions
        sin_t = math.sin(self.phase_time)
        cos_t = math.cos(self.phase_time)

        # Differential steering adjustments
        left_turn_bias = -self.turn_rate * 0.18
        right_turn_bias = self.turn_rate * 0.18

        # Left leg trajectory (Swings forward when sin_t > 0)
        # When left leg swings forward, knee bends for ground clearance
        left_knee_lift = max(0.0, sin_t) * self.knee_pitch_amp
        left_hip_p = self.nominal_standing["left_hip_pitch"] - (sin_t * self.hip_pitch_amp) + left_turn_bias
        left_knee_p = self.nominal_standing["left_knee_pitch"] + left_knee_lift
        left_ankle_p = self.nominal_standing["left_ankle_pitch"] + (sin_t * self.ankle_pitch_amp * 0.6)

        # Right leg trajectory (Opposite phase to left leg)
        right_knee_lift = max(0.0, -sin_t) * self.knee_pitch_amp
        right_hip_p = self.nominal_standing["right_hip_pitch"] + (sin_t * self.hip_pitch_amp) + right_turn_bias
        right_knee_p = self.nominal_standing["right_knee_pitch"] + right_knee_lift
        right_ankle_p = self.nominal_standing["right_ankle_pitch"] - (sin_t * self.ankle_pitch_amp * 0.6)

        # Lateral weight shift via hip roll (shifts weight over stance foot)
        lateral_roll = cos_t * self.lateral_roll_amp
        left_hip_r = self.nominal_standing["left_hip_roll"] + lateral_roll
        right_hip_r = self.nominal_standing["right_hip_roll"] + lateral_roll

        # Arm swing: counter-oscillates opposite to leg movement for dynamic balance
        left_arm_p = self.nominal_standing["left_shoulder_pitch"] + (sin_t * self.arm_swing_amp)
        right_arm_p = self.nominal_standing["right_shoulder_pitch"] - (sin_t * self.arm_swing_amp)

        targets = {
            "neck_pitch": 0.0,
            "left_shoulder_pitch": left_arm_p,
            "left_elbow_pitch": 0.35 + abs(sin_t) * 0.15,
            "right_shoulder_pitch": right_arm_p,
            "right_elbow_pitch": 0.35 + abs(sin_t) * 0.15,
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
