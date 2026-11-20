"""
Feedback-based balance controller for the humanoid robot.
Uses dual PID controllers (pitch and roll) to compute corrective ankle and hip joint offsets.
Estimates Center of Mass (COM) and support polygon to determine balance stability condition.
"""

import math
from typing import Dict, Any, List, Tuple
from python.utils.pid import PIDController
from python.utils.math_utils import (
    compute_center_of_mass,
    compute_support_polygon,
    is_point_in_polygon_2d,
    rad_to_deg,
    clamp,
)
import pybullet as p


class BalanceController:
    def __init__(self, robot_id: int):
        self.robot_id = robot_id
        self.enabled = True

        # Desired torso orientation in radians (upright posture: roll=0, pitch=0)
        self.desired_roll = 0.0
        self.desired_pitch = 0.03  # slight natural 1.7 deg forward lean for stability

        # Pitch PID controller: corrects forward/backward tilt using ankle and hip pitch
        self.pitch_pid = PIDController(
            kp=1.2,
            ki=0.05,
            kd=0.25,
            min_output=-0.40,
            max_output=0.40,
            integral_limit=0.15,
        )

        # Roll PID controller: corrects lateral tilt using hip roll
        self.roll_pid = PIDController(
            kp=0.9,
            ki=0.03,
            kd=0.20,
            min_output=-0.25,
            max_output=0.25,
            integral_limit=0.10,
        )

        # Cache link masses for Center of Mass calculation
        self._link_masses: List[float] = []
        self._link_indices: List[int] = []
        self._init_link_properties()

        self.last_status = "STABLE"
        self.com = (0.0, 0.0, 0.0)
        self.support_polygon: List[Tuple[float, float]] = []

    def _init_link_properties(self):
        """Retrieve masses of base link (torso) and all child links."""
        # Base link mass
        base_dyn = p.getDynamicsInfo(self.robot_id, -1)
        self._link_masses.append(base_dyn[0])
        self._link_indices.append(-1)

        num_joints = p.getNumJoints(self.robot_id)
        for i in range(num_joints):
            dyn = p.getDynamicsInfo(self.robot_id, i)
            self._link_masses.append(dyn[0])
            self._link_indices.append(i)

    def set_pid_gains(
        self,
        pitch_kp: float = None,
        pitch_ki: float = None,
        pitch_kd: float = None,
        roll_kp: float = None,
        roll_ki: float = None,
        roll_kd: float = None,
    ):
        """Adjust PID parameters dynamically."""
        self.pitch_pid.set_gains(pitch_kp, pitch_ki, pitch_kd)
        self.roll_pid.set_gains(roll_kp, roll_ki, roll_kd)

    def update(
        self, imu_data: Dict[str, Any], dt: float, walking_active: bool = False
    ) -> Dict[str, Any]:
        """
        Calculate corrective joint angle offsets to maintain balance.
        Returns corrective joint command offsets and balance diagnostics.
        """
        roll = imu_data["roll"]
        pitch = imu_data["pitch"]

        # Calculate errors
        pitch_error = self.desired_pitch - pitch
        roll_error = self.desired_roll - roll

        corrective_pitch = 0.0
        corrective_roll = 0.0

        if self.enabled:
            # Scale down balance reaction during active walking swing phase to avoid fighting the gait
            gain_scale = 0.6 if walking_active else 1.0
            corrective_pitch = self.pitch_pid.update(pitch_error, dt) * gain_scale
            corrective_roll = self.roll_pid.update(roll_error, dt) * gain_scale

        # Compute Center of Mass (COM)
        positions = []
        base_pos, _ = p.getBasePositionAndOrientation(self.robot_id)
        positions.append(base_pos)

        left_foot_pos = base_pos
        right_foot_pos = base_pos

        for i in range(p.getNumJoints(self.robot_id)):
            link_state = p.getLinkState(self.robot_id, i)
            link_pos = link_state[0]
            positions.append(link_pos)
            # Joint 8 is left ankle / foot, Joint 12 is right ankle / foot
            if i == 8:
                left_foot_pos = link_pos
            elif i == 12:
                right_foot_pos = link_pos

        self.com = compute_center_of_mass(self._link_masses, positions)
        self.support_polygon = compute_support_polygon(left_foot_pos, right_foot_pos)
        com_in_support = is_point_in_polygon_2d(self.com[0], self.com[1], self.support_polygon)

        # Determine balance condition
        abs_roll_deg = abs(rad_to_deg(roll))
        abs_pitch_deg = abs(rad_to_deg(pitch))
        max_tilt = max(abs_roll_deg, abs_pitch_deg)

        if max_tilt > 45.0 or base_pos[2] < 0.45:
            self.last_status = "FALLEN"
        elif max_tilt > 25.0:
            self.last_status = "FALLING"
        elif max_tilt > 12.0 or not com_in_support:
            self.last_status = "UNSTABLE"
        elif max_tilt > 4.0:
            self.last_status = "BALANCING"
        else:
            self.last_status = "STABLE"

        # Corrective joint offsets (to be added to nominal standing or walking joint targets)
        # Pitch correction: forward tilt (positive pitch error) -> lean back: ankle pitch down, hip pitch forward
        offsets = {
            "left_ankle_pitch": corrective_pitch * 0.8,
            "right_ankle_pitch": corrective_pitch * 0.8,
            "left_hip_pitch": -corrective_pitch * 0.5,
            "right_hip_pitch": -corrective_pitch * 0.5,
            "left_hip_roll": corrective_roll * 0.6,
            "right_hip_roll": corrective_roll * 0.6,
        }

        return {
            "balance_status": self.last_status,
            "roll_error_deg": round(rad_to_deg(roll_error), 2),
            "pitch_error_deg": round(rad_to_deg(pitch_error), 2),
            "corrective_pitch": round(corrective_pitch, 4),
            "corrective_roll": round(corrective_roll, 4),
            "center_of_mass": [round(c, 3) for c in self.com],
            "com_in_support": com_in_support,
            "support_polygon": self.support_polygon,
            "offsets": offsets,
        }

    def reset(self):
        self.pitch_pid.reset()
        self.roll_pid.reset()
        self.last_status = "STABLE"
