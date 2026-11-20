"""
Simulated distance sensor using PyBullet ray tests.
Casts front, left, and right rays to detect nearby obstacles.
"""

import math
from typing import Dict, Any, List, Tuple
import pybullet as p


class DistanceSensor:
    def __init__(
        self,
        robot_id: int,
        max_range: float = 3.5,
        left_angle_deg: float = 35.0,
        right_angle_deg: float = -35.0,
    ):
        self.robot_id = robot_id
        self.max_range = float(max_range)
        self.left_angle_rad = math.radians(left_angle_deg)
        self.right_angle_rad = math.radians(right_angle_deg)

    def read(self) -> Dict[str, Any]:
        """
        Cast three rays (front, left, right) from the torso forward into the environment.
        Returns distance readings, ray start/end points, and hit points for Godot visualization.
        """
        pos, orn = p.getBasePositionAndOrientation(self.robot_id)
        euler = p.getEulerFromQuaternion(orn)
        yaw = euler[2]

        # Ray origin slightly forward from torso center
        sensor_height = pos[2] + 0.10
        origin_x = pos[0] + 0.15 * math.cos(yaw)
        origin_y = pos[1] + 0.15 * math.sin(yaw)
        ray_from = [origin_x, origin_y, sensor_height]

        angles = {
            "front": yaw,
            "left": yaw + self.left_angle_rad,
            "right": yaw + self.right_angle_rad,
        }

        ray_from_list = []
        ray_to_list = []

        for key in ["front", "left", "right"]:
            theta = angles[key]
            to_x = origin_x + self.max_range * math.cos(theta)
            to_y = origin_y + self.max_range * math.sin(theta)
            to_z = sensor_height
            ray_from_list.append(ray_from)
            ray_to_list.append([to_x, to_y, to_z])

        # Execute batch ray cast in PyBullet
        results = p.rayTestBatch(ray_from_list, ray_to_list)

        readings = {}
        rays_visualization = []
        names = ["front", "left", "right"]

        for idx, res in enumerate(results):
            name = names[idx]
            hit_object_id = res[0]
            hit_fraction = res[2]
            hit_position = res[3]

            # If hit self or ground (z < 0.05), ignore as obstacle
            if hit_object_id == self.robot_id or (hit_fraction < 1.0 and hit_position[2] < 0.05):
                distance = self.max_range
                hit_pos = ray_to_list[idx]
                has_hit = False
            elif hit_fraction < 1.0:
                distance = hit_fraction * self.max_range
                hit_pos = list(hit_position)
                has_hit = True
            else:
                distance = self.max_range
                hit_pos = ray_to_list[idx]
                has_hit = False

            readings[f"{name}_distance"] = round(distance, 3)
            readings[f"{name}_hit"] = has_hit

            rays_visualization.append({
                "name": name,
                "from": ray_from,
                "to": ray_to_list[idx],
                "hit_position": hit_pos,
                "has_hit": has_hit,
                "distance": round(distance, 3),
            })

        readings["rays"] = rays_visualization
        readings["min_distance"] = min(
            readings["front_distance"], readings["left_distance"], readings["right_distance"]
        )
        return readings
