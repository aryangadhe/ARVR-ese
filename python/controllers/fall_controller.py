"""
Fall detection, recovery state machine, and disturbance impulse controller.
Manages physical external forces (pushes) and robot state transitions.
"""

from typing import Dict, Any, Tuple, Optional
import pybullet as p
from python.utils.math_utils import rad_to_deg


class FallController:
    # System states
    STATE_IDLE = "IDLE"
    STATE_STANDING = "STANDING"
    STATE_WALKING = "WALKING"
    STATE_BALANCING = "BALANCING"
    STATE_UNSTABLE = "UNSTABLE"
    STATE_RECOVERING = "RECOVERING"
    STATE_FALLING = "FALLING"
    STATE_FALLEN = "FALLEN"

    def __init__(self, robot_id: int):
        self.robot_id = robot_id
        self.state = self.STATE_STANDING
        self.fall_count = 0
        self.recovering_timer = 0.0

        # Active disturbance push parameters
        self.push_active = False
        self.push_force = [0.0, 0.0, 0.0]
        self.push_duration = 0.0
        self.push_timer = 0.0

    def apply_push(self, magnitude: float = 100.0, direction: str = "forward", duration: float = 0.15):
        """
        Apply a directional disturbance force to the robot's torso.
        magnitude: Force in Newtons.
        direction: 'forward', 'backward', 'left', 'right', or custom angle.
        duration: Impulse duration in seconds.
        """
        dir_map = {
            "forward": [1.0, 0.0, 0.0],
            "backward": [-1.0, 0.0, 0.0],
            "left": [0.0, 1.0, 0.0],
            "right": [0.0, -1.0, 0.0],
        }
        vec = dir_map.get(direction.lower(), [1.0, 0.0, 0.0])

        self.push_force = [v * magnitude for v in vec]
        self.push_duration = max(0.05, duration)
        self.push_timer = 0.0
        self.push_active = True

    def apply_custom_force(self, fx: float, fy: float, fz: float, duration: float = 0.15):
        """Apply arbitrary 3D force vector in Newtons."""
        self.push_force = [fx, fy, fz]
        self.push_duration = max(0.05, duration)
        self.push_timer = 0.0
        self.push_active = True

    def update(
        self,
        imu_data: Dict[str, Any],
        dt: float,
        is_walking: bool,
        balance_status: str,
    ) -> Dict[str, Any]:
        """
        Apply active forces and update state machine transitions.
        """
        # Apply physical disturbance impulse if active
        if self.push_active:
            pos, _ = p.getBasePositionAndOrientation(self.robot_id)
            # Apply force at upper torso in world frame
            p.applyExternalForce(
                objectUniqueId=self.robot_id,
                linkIndex=-1,  # torso base link
                forceObj=self.push_force,
                posObj=[pos[0], pos[1], pos[2] + 0.15],
                flags=p.WORLD_FRAME,
            )
            self.push_timer += dt
            if self.push_timer >= self.push_duration:
                self.push_active = False

        # State evaluation based on physical measurements
        pos, _ = p.getBasePositionAndOrientation(self.robot_id)
        roll_deg = abs(imu_data["roll_deg"])
        pitch_deg = abs(imu_data["pitch_deg"])
        max_tilt = max(roll_deg, pitch_deg)
        height = pos[2]

        prev_state = self.state

        # State transition logic
        if height < 0.45 or max_tilt > 50.0:
            self.state = self.STATE_FALLEN
            if prev_state != self.STATE_FALLEN:
                self.fall_count += 1
        elif max_tilt > 28.0 or (height < 0.65 and max_tilt > 20.0):
            self.state = self.STATE_FALLING
        elif self.state == self.STATE_FALLEN:
            # Stays fallen until explicit reset
            pass
        elif prev_state in (self.STATE_UNSTABLE, self.STATE_FALLING) and max_tilt < 12.0:
            # Heading back towards upright
            self.state = self.STATE_RECOVERING
            self.recovering_timer = 1.0
        elif self.state == self.STATE_RECOVERING:
            self.recovering_timer -= dt
            if self.recovering_timer <= 0:
                self.state = self.STATE_WALKING if is_walking else self.STATE_STANDING
        elif max_tilt > 12.0 or balance_status == "UNSTABLE":
            self.state = self.STATE_UNSTABLE
        elif is_walking:
            self.state = self.STATE_WALKING
        elif balance_status == "BALANCING":
            self.state = self.STATE_BALANCING
        else:
            self.state = self.STATE_STANDING

        return {
            "state": self.state,
            "fall_count": self.fall_count,
            "push_active": self.push_active,
            "applied_push_force": self.push_force if self.push_active else [0.0, 0.0, 0.0],
            "torso_height": round(height, 3),
            "max_tilt_deg": round(max_tilt, 2),
        }

    def reset(self):
        self.state = self.STATE_STANDING
        self.push_active = False
        self.push_timer = 0.0
        self.recovering_timer = 0.0

