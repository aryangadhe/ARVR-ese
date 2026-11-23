"""
Individual joint controller for the humanoid robot.
Provides position and velocity motor control, limit enforcement, and state reporting.
"""

import math
from typing import Dict, Any, List, Optional
import pybullet as p
from python.utils.math_utils import clamp, rad_to_deg, deg_to_rad


class JointController:
    def __init__(self, robot_id: int):
        self.robot_id = robot_id
        self.joints: Dict[str, Dict[str, Any]] = {}
        self._discover_joints()

    def _discover_joints(self):
        """Introspect PyBullet model to register all controllable revolute joints."""
        num_joints = p.getNumJoints(self.robot_id)
        for i in range(num_joints):
            info = p.getJointInfo(self.robot_id, i)
            joint_name = info[1].decode("utf-8")
            joint_type = info[2]
            lower_limit = info[8]
            upper_limit = info[9]
            max_force = info[10]
            max_velocity = info[11]
            link_name = info[12].decode("utf-8")

            if joint_type == p.JOINT_REVOLUTE:
                # Default target angle is 0.0 unless limits don't encompass 0
                default_target = clamp(0.0, lower_limit, upper_limit)
                self.joints[joint_name] = {
                    "index": i,
                    "link_name": link_name,
                    "lower_limit": lower_limit,
                    "upper_limit": upper_limit,
                    "lower_limit_deg": rad_to_deg(lower_limit),
                    "upper_limit_deg": rad_to_deg(upper_limit),
                    "max_force": max_force if max_force > 0 else 100.0,
                    "max_velocity": max_velocity if max_velocity > 0 else 4.0,
                    "target_angle": default_target,
                    "target_angle_deg": rad_to_deg(default_target),
                    "current_angle": 0.0,
                    "current_velocity": 0.0,
                    "applied_force": 0.0,
                }

    def set_target_angle(self, joint_name: str, angle_rad: float):
        """Set target angle in radians for a named joint, clamped to joint limits."""
        if joint_name in self.joints:
            j = self.joints[joint_name]
            clamped = clamp(angle_rad, j["lower_limit"], j["upper_limit"])
            j["target_angle"] = clamped
            j["target_angle_deg"] = rad_to_deg(clamped)

    def set_target_angle_deg(self, joint_name: str, angle_deg: float):
        """Set target angle in degrees for a named joint."""
        self.set_target_angle(joint_name, deg_to_rad(angle_deg))

    def set_all_targets(self, targets: Dict[str, float]):
        """Set multiple joint targets (in radians)."""
        for name, val in targets.items():
            self.set_target_angle(name, val)

    def set_all_targets_deg(self, targets_deg: Dict[str, float]):
        """Set multiple joint targets (in degrees)."""
        for name, val in targets_deg.items():
            self.set_target_angle_deg(name, val)

    def apply_control(self):
        """Send target position commands to PyBullet joint motors."""
        for name, j in self.joints.items():
            is_leg = "hip" in name or "knee" in name or "ankle" in name
            is_arm = "shoulder" in name or "elbow" in name
            
            # High-torque calibrated gains for biped stance and upper-limb manipulation
            if is_leg:
                max_force = 350.0
                p_gain = 0.75
                v_gain = 1.0
            elif is_arm:
                max_force = 250.0
                p_gain = 0.95
                v_gain = 1.0
            else:
                max_force = j["max_force"]
                p_gain = 0.45
                v_gain = 1.2

            p.setJointMotorControl2(
                bodyIndex=self.robot_id,
                jointIndex=j["index"],
                controlMode=p.POSITION_CONTROL,
                targetPosition=j["target_angle"],
                maxVelocity=j["max_velocity"],
                force=max_force,
                positionGain=p_gain,
                velocityGain=v_gain,
            )

    def update_states(self) -> Dict[str, Any]:
        """Read current joint positions, velocities, and reaction forces from PyBullet."""
        states = {}
        for name, j in self.joints.items():
            state = p.getJointState(self.robot_id, j["index"])
            curr_pos = state[0]
            curr_vel = state[1]
            applied_force = state[3]

            j["current_angle"] = curr_pos
            j["current_velocity"] = curr_vel
            j["applied_force"] = applied_force

            states[name] = {
                "index": j["index"],
                "target_deg": round(j["target_angle_deg"], 1),
                "current_deg": round(rad_to_deg(curr_pos), 1),
                "target_rad": round(j["target_angle"], 3),
                "current_rad": round(curr_pos, 3),
                "velocity": round(curr_vel, 3),
                "force": round(applied_force, 2),
                "lower_limit_deg": round(j["lower_limit_deg"], 1),
                "upper_limit_deg": round(j["upper_limit_deg"], 1),
            }
        return states

    def reset_to_pose(self, pose: Dict[str, float]):
        """Immediately reset joints to target pose without motor delay (used on simulation reset)."""
        for name, angle in pose.items():
            if name in self.joints:
                j = self.joints[name]
                clamped = clamp(angle, j["lower_limit"], j["upper_limit"])
                j["target_angle"] = clamped
                j["target_angle_deg"] = rad_to_deg(clamped)
                p.resetJointState(self.robot_id, j["index"], targetValue=clamped, targetVelocity=0.0)

