"""
Feedback-based balance controller for the humanoid robot.
Uses dual PID controllers (pitch and roll) to compute corrective joint offsets.
Calculates 3D Center of Mass (COM), ground projection, support polygon geometry,
and live balance error for real-time stability monitoring.
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

        # Desired torso orientation in radians (strictly upright vertical)
        self.desired_roll = 0.0
        self.desired_pitch = 0.0

        # Pitch PID controller: corrects forward/backward tilt
        self.pitch_pid = PIDController(
            kp=1.1,
            ki=0.0,
            kd=0.20,
            min_output=-0.30,
            max_output=0.30,
            integral_limit=0.0,
        )

        # Roll PID controller: corrects lateral tilt
        self.roll_pid = PIDController(
            kp=0.8,
            ki=0.0,
            kd=0.15,
            min_output=-0.20,
            max_output=0.20,
            integral_limit=0.0,
        )

        # Cache link masses for Center of Mass calculation
        self._link_masses: List[float] = []
        self._link_indices: List[int] = []
        self._init_link_properties()

        self.last_status = "STABLE"
        self.com = (0.0, 0.0, 0.0)
        self.support_polygon: List[Tuple[float, float]] = []
        self.balance_error = 0.0
        self.total_balance_error = 0.0
        self.balance_samples = 0

    def _init_link_properties(self):
        """Retrieve masses of base link (torso) and all child links."""
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

    def get_pid_gains(self) -> Dict[str, float]:
        """Return current PID gains dictionary."""
        return {
            "pitch_kp": self.pitch_pid.kp,
            "pitch_ki": self.pitch_pid.ki,
            "pitch_kd": self.pitch_pid.kd,
            "roll_kp": self.roll_pid.kp,
            "roll_ki": self.roll_pid.ki,
            "roll_kd": self.roll_pid.kd,
        }

    def update(
        self, imu_data: Dict[str, Any], dt: float, walking_active: bool = False
    ) -> Dict[str, Any]:
        """
        Calculate corrective joint angle offsets to maintain balance and compile metrics.
        """
        roll = imu_data.get("raw_roll", imu_data.get("roll", 0.0))
        pitch = imu_data.get("raw_pitch", imu_data.get("pitch", 0.0))

        # Calculate errors (desired - current)
        pitch_error = self.desired_pitch - pitch
        roll_error = self.desired_roll - roll

        corrective_pitch = 0.0
        corrective_roll = 0.0

        if self.enabled:
            corrective_pitch = self.pitch_pid.update(pitch_error, dt)
            corrective_roll = self.roll_pid.update(roll_error, dt)

        # 1. Compute accurate 3D Center of Mass (COM)
        positions = []
        base_pos, _ = p.getBasePositionAndOrientation(self.robot_id)
        positions.append(base_pos)

        left_foot_pos = base_pos
        right_foot_pos = base_pos

        for i in range(p.getNumJoints(self.robot_id)):
            link_state = p.getLinkState(self.robot_id, i)
            link_pos = link_state[0]
            positions.append(link_pos)
            if i == 8:
                left_foot_pos = link_pos
            elif i == 12:
                right_foot_pos = link_pos

        self.com = compute_center_of_mass(self._link_masses, positions)

        # 2. Foot contact evaluation with ground
        contacts_left = p.getContactPoints(self.robot_id, linkIndexA=8)
        contacts_right = p.getContactPoints(self.robot_id, linkIndexA=12)
        l_grounded = len(contacts_left) > 0
        r_grounded = len(contacts_right) > 0

        # 3. Compute 2D Support Polygon and COM Ground Projection
        self.support_polygon = compute_support_polygon(
            left_foot_pos, right_foot_pos, foot_length=0.24, foot_width=0.14
        )
        com_in_support = is_point_in_polygon_2d(self.com[0], self.com[1], self.support_polygon)

        # Polygon centroid
        if self.support_polygon:
            poly_cx = sum(pt[0] for pt in self.support_polygon) / len(self.support_polygon)
            poly_cy = sum(pt[1] for pt in self.support_polygon) / len(self.support_polygon)
            self.balance_error = math.sqrt((self.com[0] - poly_cx) ** 2 + (self.com[1] - poly_cy) ** 2)
        else:
            self.balance_error = 0.0

        self.total_balance_error += self.balance_error
        self.balance_samples += 1
        avg_balance_error = round(self.total_balance_error / max(1, self.balance_samples), 4)

        # 4. Determine live balance status
        abs_roll_deg = abs(rad_to_deg(roll))
        abs_pitch_deg = abs(rad_to_deg(pitch))
        max_tilt = max(abs_roll_deg, abs_pitch_deg)

        if max_tilt > 45.0 or base_pos[2] < 0.40:
            self.last_status = "FALLEN"
        elif max_tilt > 25.0:
            self.last_status = "FALLING"
        elif max_tilt > 12.0 or not com_in_support:
            self.last_status = "UNSTABLE"
        elif max_tilt > 6.0:
            self.last_status = "WARNING"
        elif max_tilt > 3.0:
            self.last_status = "BALANCING"
        else:
            self.last_status = "STABLE"

        # 5. Restoring joint offsets via hips
        # Negative feedback: when tilted forward (pitch > 0), corrective_pitch < 0,
        # so -corrective_pitch extends thighs, pulling torso upright.
        # Both hip roll joints have axis [1, 0, 0] in URDF, so parallel same-sign rotation tilts pelvis laterally.
        hip_pitch_scale = 0.80 if walking_active else 0.90
        hip_roll_scale = 0.30 if walking_active else 0.40

        offsets = {
            "left_hip_pitch": -corrective_pitch * hip_pitch_scale,
            "right_hip_pitch": -corrective_pitch * hip_pitch_scale,
            "left_hip_roll": -corrective_roll * hip_roll_scale,
            "right_hip_roll": -corrective_roll * hip_roll_scale,
            "left_ankle_pitch": 0.0,
            "right_ankle_pitch": 0.0,
        }

        return {
            "balance_status": self.last_status,
            "roll_error_deg": round(rad_to_deg(roll_error), 2),
            "pitch_error_deg": round(rad_to_deg(pitch_error), 2),
            "corrective_pitch": round(corrective_pitch, 4),
            "corrective_roll": round(corrective_roll, 4),
            "center_of_mass": [round(c, 3) for c in self.com],
            "com_ground_projection": [round(self.com[0], 3), round(self.com[1], 3), 0.0],
            "com_in_support": com_in_support,
            "support_polygon": [[round(p[0], 3), round(p[1], 3)] for p in self.support_polygon],
            "balance_error": round(self.balance_error, 4),
            "average_balance_error": avg_balance_error,
            "foot_contacts": {
                "left": len(contacts_left),
                "right": len(contacts_right),
                "left_grounded": l_grounded,
                "right_grounded": r_grounded,
            },
            "pid_gains": {
                "pitch_kp": self.pitch_pid.kp,
                "pitch_ki": self.pitch_pid.ki,
                "pitch_kd": self.pitch_pid.kd,
                "roll_kp": self.roll_pid.kp,
                "roll_ki": self.roll_pid.ki,
                "roll_kd": self.roll_pid.kd,
            },
            "offsets": offsets,
        }

    def reset(self):
        self.pitch_pid.reset()
        self.roll_pid.reset()
        self.last_status = "STABLE"
        self.total_balance_error = 0.0
        self.balance_samples = 0
