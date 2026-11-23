"""
Simulated Inertial Measurement Unit (IMU) sensor for the humanoid robot.
Extracts roll, pitch, yaw, angular velocities, and estimated accelerations from PyBullet.
"""

import math
from typing import Dict, Any, Tuple
import pybullet as p
from python.utils.math_utils import rad_to_deg, LowPassFilter


class IMUSensor:
    def __init__(self, robot_id: int):
        self.robot_id = robot_id
        self.prev_linear_vel = (0.0, 0.0, 0.0)
        self.linear_accel = (0.0, 0.0, 0.0)

        # Filters for roll, pitch, yaw rate
        self.roll_filter = LowPassFilter(alpha=0.4)
        self.pitch_filter = LowPassFilter(alpha=0.4)

    def update(self, dt: float) -> Dict[str, Any]:
        """Query PyBullet for ground-truth base link kinematics and simulate IMU readings."""
        pos, orn = p.getBasePositionAndOrientation(self.robot_id)
        lin_vel, ang_vel = p.getBaseVelocity(self.robot_id)

        # Body rotation matrix (mapping body frame to world frame)
        m = p.getMatrixFromQuaternion(orn)
        # Projection of world vertical Up vector [0, 0, 1] onto body principal axes:
        # m = [m00, m01, m02, m10, m11, m12, m20, m21, m22]
        # This provides heading-invariant body pitch and roll across the entire 360° arena.
        r20, r21, r22 = m[6], m[7], m[8]
        raw_pitch = -math.asin(max(-1.0, min(1.0, r20)))
        raw_roll = math.asin(max(-1.0, min(1.0, r21)))

        # Global heading yaw in radians from PyBullet Euler
        euler = p.getEulerFromQuaternion(orn)
        raw_yaw = euler[2]

        filtered_roll = self.roll_filter.update(raw_roll)
        filtered_pitch = self.pitch_filter.update(raw_pitch)

        # Body-frame angular velocity (omega_body = R^T * omega_world)
        w_roll = m[0] * ang_vel[0] + m[3] * ang_vel[1] + m[6] * ang_vel[2]
        w_pitch = m[1] * ang_vel[0] + m[4] * ang_vel[1] + m[7] * ang_vel[2]
        w_yaw = m[2] * ang_vel[0] + m[5] * ang_vel[1] + m[8] * ang_vel[2]

        # Estimate linear acceleration in world frame
        if dt > 1e-6:
            ax = (lin_vel[0] - self.prev_linear_vel[0]) / dt
            ay = (lin_vel[1] - self.prev_linear_vel[1]) / dt
            az = (lin_vel[2] - self.prev_linear_vel[2]) / dt + 9.81  # Account for gravity reaction
            self.linear_accel = (ax, ay, az)
        self.prev_linear_vel = lin_vel

        return {
            "orientation_quat": [orn[0], orn[1], orn[2], orn[3]],
            "roll": filtered_roll,
            "pitch": filtered_pitch,
            "raw_roll": raw_roll,
            "raw_pitch": raw_pitch,
            "yaw": raw_yaw,
            "roll_deg": rad_to_deg(filtered_roll),
            "pitch_deg": rad_to_deg(filtered_pitch),
            "yaw_deg": rad_to_deg(raw_yaw),
            "angular_velocity": [w_roll, w_pitch, w_yaw],
            "world_angular_velocity": [ang_vel[0], ang_vel[1], ang_vel[2]],
            "linear_velocity": [lin_vel[0], lin_vel[1], lin_vel[2]],
            "linear_acceleration": list(self.linear_accel),
        }

    def reset(self):
        self.prev_linear_vel = (0.0, 0.0, 0.0)
        self.linear_accel = (0.0, 0.0, 0.0)
        self.roll_filter.reset()
        self.pitch_filter.reset()

