"""
Fall detection, recovery state machine, disturbance impulse controller,
and recovery performance tracking.
Manages physical external forces (pushes) and robot state transitions.
"""

from typing import Dict, Any, List, Optional
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
        self.successful_recoveries = 0
        self.recovery_times: List[float] = []
        self.recovering_timer = 0.0

        # Latch to prevent duplicate fall counts from physical bounce oscillations
        self.has_fallen_latch = False
        self.upright_time = 0.0

        # Recovery measurement
        self.disturbance_active = False
        self.disturbance_start_time = 0.0
        self.sim_elapsed_time = 0.0

        # Active disturbance push parameters
        self.push_active = False
        self.push_force = [0.0, 0.0, 0.0]
        self.push_duration = 0.0
        self.push_timer = 0.0

    def apply_push(self, magnitude: float = 100.0, direction: str = "forward", duration: float = 0.15):
        """
        Apply a directional disturbance force to the robot's upper torso.
        direction: 'forward', 'backward', 'left', 'right'.
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
        self.disturbance_active = True
        self.disturbance_start_time = self.sim_elapsed_time

    def apply_custom_force(self, fx: float, fy: float, fz: float, duration: float = 0.15):
        """Apply arbitrary 3D force vector in Newtons."""
        self.push_force = [fx, fy, fz]
        self.push_duration = max(0.05, duration)
        self.push_timer = 0.0
        self.push_active = True
        self.disturbance_active = True
        self.disturbance_start_time = self.sim_elapsed_time

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
        self.sim_elapsed_time += dt

        # 1. Apply physical disturbance impulse if active
        if self.push_active:
            pos, _ = p.getBasePositionAndOrientation(self.robot_id)
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

        # 2. State evaluation based on physical measurements
        pos, _ = p.getBasePositionAndOrientation(self.robot_id)
        roll_deg = abs(imu_data.get("roll_deg", 0.0))
        pitch_deg = abs(imu_data.get("pitch_deg", 0.0))
        max_tilt = max(roll_deg, pitch_deg)
        height = pos[2]

        prev_state = self.state

        # Check if robot is completely upright and stable to clear fallen latch
        if height > 0.72 and max_tilt < 12.0:
            self.upright_time += dt
            if self.upright_time > 0.4:
                self.has_fallen_latch = False
        else:
            self.upright_time = 0.0

        # State transition logic
        if height < 0.45 or max_tilt > 50.0:
            self.state = self.STATE_FALLEN
            if not self.has_fallen_latch:
                self.fall_count += 1
                self.has_fallen_latch = True
                self.disturbance_active = False

        elif self.has_fallen_latch:
            # Stays in FALLEN state until physically reset or restored
            self.state = self.STATE_FALLEN

        elif max_tilt > 28.0 or (height < 0.65 and max_tilt > 20.0):
            self.state = self.STATE_FALLING
            if not self.disturbance_active:
                self.disturbance_active = True
                self.disturbance_start_time = self.sim_elapsed_time

        elif prev_state in (self.STATE_UNSTABLE, self.STATE_FALLING) and max_tilt < 12.0:
            # Heading back towards upright
            self.state = self.STATE_RECOVERING
            self.recovering_timer = 0.8

        elif self.state == self.STATE_RECOVERING:
            self.recovering_timer -= dt
            if self.recovering_timer <= 0:
                self.state = self.STATE_WALKING if is_walking else self.STATE_STANDING
                # Record successful recovery event and elapsed recovery duration
                if self.disturbance_active:
                    rec_time = max(0.1, round(self.sim_elapsed_time - self.disturbance_start_time, 2))
                    self.recovery_times.append(rec_time)
                    self.successful_recoveries += 1
                    self.disturbance_active = False

        elif max_tilt > 12.0 or balance_status == "UNSTABLE":
            self.state = self.STATE_UNSTABLE
            if not self.disturbance_active:
                self.disturbance_active = True
                self.disturbance_start_time = self.sim_elapsed_time

        elif is_walking:
            self.state = self.STATE_WALKING

        elif balance_status == "BALANCING":
            self.state = self.STATE_BALANCING

        else:
            self.state = self.STATE_STANDING
            if self.disturbance_active and prev_state in (self.STATE_BALANCING, self.STATE_UNSTABLE):
                rec_time = max(0.1, round(self.sim_elapsed_time - self.disturbance_start_time, 2))
                self.recovery_times.append(rec_time)
                self.successful_recoveries += 1
                self.disturbance_active = False

        avg_recovery = (
            round(sum(self.recovery_times) / len(self.recovery_times), 2)
            if self.recovery_times
            else 0.0
        )

        return {
            "state": self.state,
            "fall_count": self.fall_count,
            "successful_recoveries": self.successful_recoveries,
            "recovery_times": list(self.recovery_times[-5:]),
            "average_recovery_time": avg_recovery,
            "push_active": self.push_active,
            "applied_push_force": self.push_force if self.push_active else [0.0, 0.0, 0.0],
            "torso_height": round(height, 3),
            "max_tilt_deg": round(max_tilt, 2),
        }

    def reset(self, reset_counters: bool = False):
        """Reset state machine. If reset_counters is True, clear all statistics."""
        self.state = self.STATE_STANDING
        self.push_active = False
        self.push_timer = 0.0
        self.recovering_timer = 0.0
        self.has_fallen_latch = False
        self.upright_time = 0.0
        self.disturbance_active = False
        if reset_counters:
            self.fall_count = 0
            self.successful_recoveries = 0
            self.recovery_times.clear()
            self.sim_elapsed_time = 0.0
