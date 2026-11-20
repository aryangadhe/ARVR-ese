"""
Physics simulation manager using PyBullet.
Handles physics world setup, ground plane, humanoid robot lifecycle,
and dynamic obstacle placement (cubes, cylinders, barriers).
"""

import os
from typing import Dict, Any, List, Optional, Tuple
import pybullet as p
import pybullet_data
from python.robot import HumanoidRobot


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

        self.initialize()

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

        # Configure foot friction
        num_joints = p.getNumJoints(self.robot_id)
        for i in range(num_joints):
            info = p.getJointInfo(self.robot_id, i)
            link_name = info[12].decode("utf-8")
            if "foot" in link_name:
                p.changeDynamics(
                    self.robot_id,
                    i,
                    lateralFriction=1.2,
                    spinningFriction=0.1,
                    rollingFriction=0.1,
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

    def spawn_obstacle(
        self,
        obstacle_type: str = "cube",
        position: List[float] = None,
        size: List[float] = None,
    ) -> int:
        """
        Spawn an obstacle in the physics world.
        obstacle_type: 'cube', 'cylinder', or 'wall'
        position: [x, y, z]
        size: [half_x, half_y, half_z] for box, or [radius, height] for cylinder
        """
        if position is None:
            position = [1.8, 0.0, 0.4]

        col_id = -1
        vis_id = -1

        if obstacle_type.lower() == "cylinder":
            radius = size[0] if size else 0.25
            height = size[1] if size else 0.8
            col_id = p.createCollisionShape(p.GEOM_CYLINDER, radius=radius, height=height)
            vis_id = p.createVisualShape(
                p.GEOM_CYLINDER,
                radius=radius,
                length=height,
                rgbaColor=[0.85, 0.35, 0.2, 1.0],
            )
        elif obstacle_type.lower() == "wall":
            half_extents = size if size else [0.1, 1.2, 0.5]
            col_id = p.createCollisionShape(p.GEOM_BOX, halfExtents=half_extents)
            vis_id = p.createVisualShape(
                p.GEOM_BOX,
                halfExtents=half_extents,
                rgbaColor=[0.3, 0.5, 0.7, 1.0],
            )
        else:  # default 'cube'
            half_extents = size if size else [0.25, 0.25, 0.4]
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
        )

        self.obstacles[body_id] = {
            "id": body_id,
            "type": obstacle_type.lower(),
            "position": position,
            "size": size,
        }
        return body_id

    def remove_obstacle(self, obstacle_id: int):
        if obstacle_id in self.obstacles:
            p.removeBody(obstacle_id)
            del self.obstacles[obstacle_id]

    def clear_all_obstacles(self):
        for obs_id in list(self.obstacles.keys()):
            p.removeBody(obs_id)
        self.obstacles.clear()

    def step(self) -> Dict[str, Any]:
        """Advance physics simulation by one time step and update robot telemetry."""
        # 1. Update robot control
        telemetry = self.robot.update(self.time_step)

        # 2. Advance PyBullet physics
        p.stepSimulation()

        # 3. Attach obstacle info to telemetry
        telemetry["obstacles"] = list(self.obstacles.values())
        return telemetry

    def reset_robot(self):
        """Reset robot to initial posture without clearing obstacles."""
        if self.robot:
            self.robot.reset()

    def close(self):
        """Disconnect PyBullet physics client."""
        if self.physics_client_id >= 0:
            p.disconnect(self.physics_client_id)
            self.physics_client_id = -1

