"""
Humanoid Robot Model & Subsystems Coordinator.
Encapsulates all sensors, controllers, kinematics, and telemetry aggregation.
"""

from typing import Dict, Any, List, Optional, Tuple
import pybullet as p
from python.sensors.imu_sensor import IMUSensor
from python.sensors.distance_sensor import DistanceSensor
from python.sensors.lidar_sensor import LidarSensor
from python.controllers.joint_controller import JointController
from python.controllers.balance_controller import BalanceController
from python.controllers.walking_controller import WalkingController
from python.controllers.fall_controller import FallController
from python.controllers.obstacle_avoidance import ObstacleAvoidanceController
from python.utils.math_utils import rad_to_deg


class HumanoidRobot:
    INITIAL_POSITION = [0.0, 0.0, 0.83]
    INITIAL_ORIENTATION = [0.0, 0.0, 0.0, 1.0]

    def __init__(self, robot_id: int):
        self.robot_id = robot_id

        # Subsystems
        self.joint_ctrl = JointController(robot_id)
        self.imu = IMUSensor(robot_id)
        self.distance_sensor = DistanceSensor(robot_id)
        self.lidar = LidarSensor(robot_id, num_rays=16, fov_deg=120.0, max_range=4.0)
        self.balance_ctrl = BalanceController(robot_id)
        self.walking_ctrl = WalkingController()
        self.fall_ctrl = FallController(robot_id)
        self.obstacle_ctrl = ObstacleAvoidanceController()

        # Manual joint overrides from Godot UI sliders
        self.manual_joint_overrides: Dict[str, float] = {}

        # Cache link mapping for visualization telemetry
        self._link_names: Dict[int, str] = {}
        self._map_links()

        # Reset to initial nominal standing pose
        self.reset()

    def _map_links(self):
        """Map link index to link name for Godot visual hierarchy synchronization."""
        num_joints = p.getNumJoints(self.robot_id)
        for i in range(num_joints):
            info = p.getJointInfo(self.robot_id, i)
            link_name = info[12].decode("utf-8")
            self._link_names[i] = link_name

    def reset(self):
        """Reset robot base position, orientation, velocities, and all joints."""
        p.resetBasePositionAndOrientation(
            self.robot_id, self.INITIAL_POSITION, self.INITIAL_ORIENTATION
        )
        p.resetBaseVelocity(self.robot_id, [0.0, 0.0, 0.0], [0.0, 0.0, 0.0])

        self.walking_ctrl.reset()
        self.balance_ctrl.reset()
        self.fall_ctrl.reset()
        self.obstacle_ctrl.reset()
        self.imu.reset()
        self.manual_joint_overrides.clear()

        # Set joints to nominal standing pose
        self.joint_ctrl.reset_to_pose(self.walking_ctrl.nominal_standing)

    def set_manual_joint(self, joint_name: str, angle_rad: float):
        """Set a user-driven manual target for an individual joint (from Godot slider)."""
        self.manual_joint_overrides[joint_name] = angle_rad

    def clear_manual_joint(self, joint_name: str):
        if joint_name in self.manual_joint_overrides:
            del self.manual_joint_overrides[joint_name]

    def clear_all_manual_joints(self):
        self.manual_joint_overrides.clear()

    def update(self, dt: float) -> Dict[str, Any]:
        """
        Main control step: updates sensors, evaluates obstacle avoidance,
        computes walking gait and balance compensation, and drives motors.
        """
        # 1. Update IMU
        imu_data = self.imu.update(dt)

        # 2. Update distance and LiDAR sensors
        distance_data = self.distance_sensor.read()
        lidar_data = self.lidar.read()

        # 3. Obstacle avoidance evaluation
        avoidance = self.obstacle_ctrl.evaluate(distance_data)
        if self.walking_ctrl.is_walking and avoidance["enabled"]:
            # Only override steering and speed if an obstacle is actively detected
            if avoidance["action"] != ObstacleAvoidanceController.ACTION_CLEAR:
                self.walking_ctrl.set_turn_rate(avoidance["turn_rate"])
                if avoidance["speed_factor"] <= 0.0:
                    self.walking_ctrl.stop_walking()

        # 4. Gait generation with active pitch and roll stabilization feedback
        gait = self.walking_ctrl.update(
            dt,
            pitch=imu_data.get("raw_pitch", imu_data["pitch"]),
            pitch_rate=imu_data["angular_velocity"][1],
            roll=imu_data.get("raw_roll", imu_data["roll"]),
            roll_rate=imu_data["angular_velocity"][0],
        )

        # 5. Balance control feedback
        balance = self.balance_ctrl.update(
            imu_data, dt, walking_active=self.walking_ctrl.is_walking
        )

        # 6. Fall detection & external disturbance
        fall = self.fall_ctrl.update(
            imu_data,
            dt,
            is_walking=self.walking_ctrl.is_walking,
            balance_status=balance["balance_status"],
        )

        # If fallen, halt walking controller
        if fall["state"] == FallController.STATE_FALLEN:
            self.walking_ctrl.stop_walking()

        # 7. Synthesize joint targets
        # Start with walking or standing nominal targets
        combined_targets = dict(gait["targets"])

        # Add balance correction offsets (if robot has not fallen)
        if fall["state"] not in (FallController.STATE_FALLEN, FallController.STATE_FALLING):
            for j_name, offset in balance["offsets"].items():
                if j_name in combined_targets:
                    combined_targets[j_name] += offset

        # Apply any active manual joint overrides from Godot UI
        for j_name, target in self.manual_joint_overrides.items():
            combined_targets[j_name] = target

        # Send target positions to joint motors in PyBullet
        self.joint_ctrl.set_all_targets(combined_targets)
        self.joint_ctrl.apply_control()

        # 8. Query updated joint states
        joint_states = self.joint_ctrl.update_states()

        # 9. Query link world poses for Godot 3D visualization synchronization
        base_pos, base_orn = p.getBasePositionAndOrientation(self.robot_id)
        links_telemetry = {
            "torso": {
                "position": [round(p, 4) for p in base_pos],
                "orientation": [round(q, 4) for q in base_orn],
            }
        }
        for idx, name in self._link_names.items():
            link_state = p.getLinkState(self.robot_id, idx)
            links_telemetry[name] = {
                "position": [round(p, 4) for p in link_state[0]],
                "orientation": [round(q, 4) for q in link_state[1]],
            }

        # 10. Compile comprehensive telemetry
        return {
            "state": fall["state"],
            "fall_count": fall["fall_count"],
            "balance": balance["balance_status"],
            "roll": round(imu_data["roll_deg"], 2),
            "pitch": round(imu_data["pitch_deg"], 2),
            "yaw": round(imu_data["yaw_deg"], 2),
            "position": [round(p, 3) for p in base_pos],
            "linear_velocity": [round(v, 3) for v in imu_data["linear_velocity"]],
            "angular_velocity": [round(w, 3) for w in imu_data["angular_velocity"]],
            "center_of_mass": balance["center_of_mass"],
            "com_ground_projection": balance["com_ground_projection"],
            "support_polygon": balance["support_polygon"],
            "balance_error": balance["balance_error"],
            "average_balance_error": balance["average_balance_error"],
            "foot_contacts": balance["foot_contacts"],
            "pid_gains": self.balance_ctrl.get_pid_gains(),
            "walking": {
                "active": self.walking_ctrl.is_walking,
                "direction": self.walking_ctrl.direction,
                "phase": gait["phase"],
                "gait_progress": gait.get("gait_progress", 0.0),
                "speed": self.walking_ctrl.speed,
                "instantaneous_speed": self.walking_ctrl.instantaneous_speed,
                "walking_distance": self.walking_ctrl.walking_distance,
                "support_leg": self.walking_ctrl.support_leg,
                "turn_rate": self.walking_ctrl.turn_rate,
                "step_length": self.walking_ctrl.step_length,
                "step_duration": self.walking_ctrl.step_duration,
            },
            "obstacle_avoidance": avoidance,
            "sensors": {
                "front_distance": distance_data["front_distance"],
                "left_distance": distance_data["left_distance"],
                "right_distance": distance_data["right_distance"],
                "min_distance": distance_data["min_distance"],
                "rays": distance_data["rays"],
                "lidar": lidar_data,
            },
            "joints": joint_states,
            "links": links_telemetry,
        }

