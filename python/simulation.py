"""
Physics simulation manager using PyBullet.
Handles physics world setup, ground plane, humanoid robot lifecycle,
dynamic obstacle placement (cubes, cylinders, walls, barriers, ramps),
collision event tracking, event logging, and scenario experiment management.
"""

import os
from typing import Dict, Any, List, Optional, Tuple
import pybullet as p
import pybullet_data
from python.robot import HumanoidRobot
from python.communication.events import EventLogger
from python.controllers.experiment_manager import ExperimentManager


class PhysicsSimulation:
    def __init__(
        self,
        gui: bool = False,
        time_step: float = 1.0 / 60.0,
        gravity: float = -9.81,
        urdf_path: Optional[str] = None,
    ):
        self.gui = gui
        self.time_step = time_step
        self.gravity = gravity

        # Resolve URDF path
        if urdf_path is None:
            base_dir = os.path.dirname(os.path.abspath(__file__))
            urdf_path = os.path.join(base_dir, "models", "humanoid.urdf")
        self.urdf_path = urdf_path

        self.physics_client_id = -1
        self.ground_id = -1
        self.robot_id = -1
        self.robot: Optional[HumanoidRobot] = None

        # Track spawned obstacles: {id: {"type": ..., "position": ..., "size": ...}}
        self.obstacles: Dict[int, Dict[str, Any]] = {}

        # Collision & analytics tracking
        self.total_collisions = 0
        self.active_collision = False

        # Structured event logger
        self.event_logger = EventLogger()
        self.grasp_constraint_id: int = -1

        # Initialize simulation
        self.initialize()

        # Experiment manager
        self.experiment_mgr = ExperimentManager(self)

    def initialize(self):
        """Connect to PyBullet, configure gravity, load ground and robot."""
        mode = p.GUI if self.gui else p.DIRECT
        self.physics_client_id = p.connect(mode)

        p.setAdditionalSearchPath(pybullet_data.getDataPath())
        p.setGravity(0, 0, self.gravity)
        p.setTimeStep(self.time_step)

        # Ground plane with high contact friction for walking traction
        self.ground_id = p.loadURDF("plane.urdf", [0, 0, 0])
        p.changeDynamics(
            self.ground_id,
            -1,
            lateralFriction=1.2,
            spinningFriction=0.1,
            rollingFriction=0.1,
            restitution=0.0,
        )

        # Load Humanoid Robot
        if not os.path.exists(self.urdf_path):
            raise FileNotFoundError(f"URDF file not found at {self.urdf_path}")

        self.robot_id = p.loadURDF(
            self.urdf_path,
            basePosition=HumanoidRobot.INITIAL_POSITION,
            baseOrientation=HumanoidRobot.INITIAL_ORIENTATION,
            flags=p.URDF_USE_INERTIA_FROM_FILE | p.URDF_USE_SELF_COLLISION,
        )

        # Configure base stabilization damping and foot friction
        p.changeDynamics(
            self.robot_id,
            -1,
            linearDamping=0.08,
            angularDamping=0.30,
        )

        num_joints = p.getNumJoints(self.robot_id)
        for i in range(num_joints):
            info = p.getJointInfo(self.robot_id, i)
            link_name = info[12].decode("utf-8")
            if "foot" in link_name:
                p.changeDynamics(
                    self.robot_id,
                    i,
                    lateralFriction=1.4,
                    spinningFriction=0.05,
                    rollingFriction=0.05,
                )

        # Initialize robot coordinator
        self.robot = HumanoidRobot(self.robot_id)

        # If in GUI mode, position camera to frame robot
        if self.gui:
            p.resetDebugVisualizerCamera(
                cameraDistance=2.5,
                cameraYaw=45,
                cameraPitch=-20,
                cameraTargetPosition=[0, 0, 0.8],
            )

    def set_time_step(self, time_step: float):
        """Adjust physics simulation time step."""
        self.time_step = max(0.002, min(0.05, float(time_step)))
        p.setTimeStep(self.time_step)

    def set_gravity(self, gravity_z: float):
        """Adjust vertical gravity acceleration."""
        self.gravity = float(gravity_z)
        p.setGravity(0, 0, self.gravity)

    def spawn_obstacle(
        self,
        obstacle_type: str = "cube",
        position: List[float] = None,
        size: List[float] = None,
    ) -> int:
        """
        Spawn an obstacle in the physics world.
        Supported types: 'cube', 'cylinder', 'wall', 'barrier', 'ramp'
        """
        obs_type = obstacle_type.lower()
        if position is None:
            position = [1.8, 0.0, 0.4]

        col_id = -1
        vis_id = -1
        orientation = [0.0, 0.0, 0.0, 1.0]

        if obs_type == "cylinder":
            radius = size[0] if size and len(size) > 0 else 0.25
            height = size[1] if size and len(size) > 1 else 0.8
            col_id = p.createCollisionShape(p.GEOM_CYLINDER, radius=radius, height=height)
            vis_id = p.createVisualShape(
                p.GEOM_CYLINDER,
                radius=radius,
                length=height,
                rgbaColor=[0.85, 0.35, 0.2, 1.0],
            )
        elif obs_type == "wall":
            half_extents = size if size and len(size) >= 3 else [0.1, 1.2, 0.5]
            col_id = p.createCollisionShape(p.GEOM_BOX, halfExtents=half_extents)
            vis_id = p.createVisualShape(
                p.GEOM_BOX,
                halfExtents=half_extents,
                rgbaColor=[0.3, 0.5, 0.7, 1.0],
            )
        elif obs_type == "barrier":
            half_extents = size if size and len(size) >= 3 else [0.15, 0.8, 0.35]
            col_id = p.createCollisionShape(p.GEOM_BOX, halfExtents=half_extents)
            vis_id = p.createVisualShape(
                p.GEOM_BOX,
                halfExtents=half_extents,
                rgbaColor=[0.95, 0.55, 0.1, 1.0],
            )
        elif obs_type == "ramp":
            half_extents = size if size and len(size) >= 3 else [1.0, 0.6, 0.05]
            col_id = p.createCollisionShape(p.GEOM_BOX, halfExtents=half_extents)
            vis_id = p.createVisualShape(
                p.GEOM_BOX,
                halfExtents=half_extents,
                rgbaColor=[0.25, 0.65, 0.85, 1.0],
            )
            # 3.5 degree gentle incline around Y axis
            orientation = p.getQuaternionFromEuler([0.0, -0.06, 0.0])
        elif obs_type == "receptacle":
            half_extents = size if size and len(size) >= 3 else [0.09, 0.09, 0.20]
            col_id = p.createCollisionShape(p.GEOM_BOX, halfExtents=half_extents)
            vis_id = p.createVisualShape(
                p.GEOM_BOX,
                halfExtents=half_extents,
                rgbaColor=[0.15, 0.75, 0.45, 1.0],
            )
        else:  # default 'cube'
            half_extents = size if size and len(size) >= 3 else [0.25, 0.25, 0.4]
            col_id = p.createCollisionShape(p.GEOM_BOX, halfExtents=half_extents)
            vis_id = p.createVisualShape(
                p.GEOM_BOX,
                halfExtents=half_extents,
                rgbaColor=[0.9, 0.55, 0.15, 1.0],
            )

        body_id = p.createMultiBody(
            baseMass=0.0,  # Static obstacle
            baseCollisionShapeIndex=col_id,
            baseVisualShapeIndex=vis_id,
            basePosition=position,
            baseOrientation=orientation,
        )

        self.obstacles[body_id] = {
            "id": body_id,
            "type": obs_type,
            "position": position,
            "size": size,
            "orientation": list(orientation),
        }

        if self.event_logger:
            self.event_logger.log(
                "Environment",
                f"Spawned {obs_type.upper()} obstacle at {position} (ID: {body_id})",
                "INFO",
            )
        return body_id

    def remove_obstacle(self, obstacle_id: int):
        if obstacle_id in self.obstacles:
            p.removeBody(obstacle_id)
            del self.obstacles[obstacle_id]

    def clear_all_obstacles(self):
        self.release_grasp_constraint()
        for obs_id in list(self.obstacles.keys()):
            p.removeBody(obs_id)
        self.obstacles.clear()
        self.total_collisions = 0
        self.active_collision = False
        if self.event_logger:
            self.event_logger.log("Environment", "Cleared all environment obstacles", "INFO")

    def create_grasp_constraint(self, target_body_id: int) -> int:
        """Attach object to robot right hand tip using PyBullet fixed joint constraint."""
        self.release_grasp_constraint()
        try:
            self.grasp_constraint_id = p.createConstraint(
                parentBodyUniqueId=self.robot_id,
                parentLinkIndex=4,
                childBodyUniqueId=target_body_id,
                childLinkIndex=-1,
                jointType=p.JOINT_FIXED,
                jointAxis=[0.0, 0.0, 0.0],
                parentFramePosition=[0.0, 0.0, -0.20],
                childFramePosition=[0.0, 0.0, 0.0],
            )
            return self.grasp_constraint_id
        except Exception as e:
            print(f"[Simulation] Failed to create grasp constraint: {e}")
            return -1

    def release_grasp_constraint(self):
        """Release grasped object and detach constraint."""
        if self.grasp_constraint_id != -1:
            try:
                p.removeConstraint(self.grasp_constraint_id)
            except Exception:
                pass
            self.grasp_constraint_id = -1

    def _check_collisions(self):
        """Evaluate physical contact points between robot links and spawned obstacles."""
        # During manipulation scenario 6, arm/hand interaction with target object is intentional
        if self.experiment_mgr and self.experiment_mgr.current_scenario_id == 6 and self.experiment_mgr.active:
            self.active_collision = False
            return

        had_collision = False
        for obs_id, info in self.obstacles.items():
            obs_type = info.get("type", "cube").lower()
            contacts = p.getContactPoints(bodyA=self.robot_id, bodyB=obs_id)
            if contacts and len(contacts) > 0:
                # If obstacle is a ramp / terrain meant to be walked on:
                # Contact on feet (link 8 or 12) is normal walking support contact.
                # Only non-foot contact (e.g. torso, knees, arms) counts as a collision.
                if obs_type == "ramp":
                    non_foot_contacts = [c for c in contacts if c[3] not in (8, 12)]
                    if non_foot_contacts:
                        had_collision = True
                        break
                else:
                    had_collision = True
                    break

        if had_collision and not self.active_collision:
            self.total_collisions += 1
            if self.event_logger:
                self.event_logger.log("Collision", "Robot collided with obstacle!", "WARNING")
        self.active_collision = had_collision

    def step(self) -> Dict[str, Any]:
        """Advance physics simulation by one time step and update robot telemetry."""
        # 1. Update robot control with live obstacle awareness
        telemetry = self.robot.update(self.time_step, obstacles=list(self.obstacles.values()))

        # 2. Update walking odometry (full 2D planar tracking)
        base_pos, _ = p.getBasePositionAndOrientation(self.robot_id)
        self.robot.walking_ctrl.update_odometry(base_pos[:2], self.time_step)

        # 3. Advance PyBullet physics
        p.stepSimulation()

        # 4. Check collisions with obstacles
        self._check_collisions()

        # 5. Advance experiment scenario if active
        if self.experiment_mgr:
            self.experiment_mgr.metrics["collisions"] = self.total_collisions
            self.experiment_mgr.update(self.time_step, telemetry)

        # 6. Attach environment info with live dynamic obstacle positions & orientations
        live_obstacles = []
        for body_id, info in self.obstacles.items():
            pos, orn = p.getBasePositionAndOrientation(body_id)
            entry = dict(info)
            entry["position"] = [round(float(x), 4) for x in pos]
            entry["orientation"] = [round(float(x), 4) for x in orn]
            live_obstacles.append(entry)
        telemetry["obstacles"] = live_obstacles
        telemetry["collision_count"] = self.total_collisions
        telemetry["active_collision"] = self.active_collision
        telemetry["events"] = self.event_logger.get_recent(25) if self.event_logger else []
        telemetry["experiment"] = self.experiment_mgr.get_state() if self.experiment_mgr else {}
        telemetry["physics"] = {
            "time_step": self.time_step,
            "frequency_hz": round(1.0 / self.time_step, 1),
            "gravity": self.gravity,
        }

        return telemetry

    def reset_robot(self):
        """Reset robot to initial posture without clearing obstacles."""
        self.release_grasp_constraint()
        if self.robot:
            self.robot.reset()
        p.changeDynamics(self.robot_id, -1, linearDamping=0.08, angularDamping=0.30)
        self.total_collisions = 0
        self.active_collision = False
        if self.event_logger:
            self.event_logger.log("Simulation", "Robot posture reset to initial nominal standing", "INFO")

    def stand_robot_in_place(self):
        """Restore robot upright at its current (X, Y) arena position without teleporting to start."""
        self.release_grasp_constraint()
        if self.robot:
            self.robot.stand_in_place()
        p.changeDynamics(self.robot_id, -1, linearDamping=0.08, angularDamping=0.30)
        self.total_collisions = 0
        self.active_collision = False
        if self.event_logger:
            self.event_logger.log("Simulation", "Robot stood upright at current position", "INFO")

    def close(self):
        """Disconnect PyBullet physics client."""
        if self.physics_client_id >= 0:
            p.disconnect(self.physics_client_id)
            self.physics_client_id = -1
