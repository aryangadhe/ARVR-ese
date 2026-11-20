"""
Simulated 2D planar LiDAR sensor using PyBullet batch raycasting.
Produces a fan of range measurements over a specified horizontal field of view.
"""

import math
from typing import Dict, Any, List
import pybullet as p


class LidarSensor:
    def __init__(
        self,
        robot_id: int,
        num_rays: int = 16,
        fov_deg: float = 120.0,
        max_range: float = 5.0,
    ):
        self.robot_id = robot_id
        self.num_rays = num_rays
        self.fov_rad = math.radians(fov_deg)
        self.max_range = float(max_range)

    def read(self) -> Dict[str, Any]:
        pos, orn = p.getBasePositionAndOrientation(self.robot_id)
        euler = p.getEulerFromQuaternion(orn)
        yaw = euler[2]

        sensor_height = pos[2] + 0.12
        origin_x = pos[0] + 0.15 * math.cos(yaw)
        origin_y = pos[1] + 0.15 * math.sin(yaw)
        ray_from = [origin_x, origin_y, sensor_height]

        angles = [
            yaw - (self.fov_rad / 2.0) + (i * self.fov_rad / max(1, self.num_rays - 1))
            for i in range(self.num_rays)
        ]

        ray_from_list = []
        ray_to_list = []
        for a in angles:
            to_x = origin_x + self.max_range * math.cos(a)
            to_y = origin_y + self.max_range * math.sin(a)
            ray_from_list.append(ray_from)
            ray_to_list.append([to_x, to_y, sensor_height])

        results = p.rayTestBatch(ray_from_list, ray_to_list)

        ranges: List[float] = []
        hits: List[List[float]] = []

        for idx, res in enumerate(results):
            hit_object_id = res[0]
            hit_fraction = res[2]
            hit_pos = res[3]

            if hit_object_id == self.robot_id or (hit_fraction < 1.0 and hit_pos[2] < 0.05):
                dist = self.max_range
                hit_pt = ray_to_list[idx]
            elif hit_fraction < 1.0:
                dist = hit_fraction * self.max_range
                hit_pt = list(hit_pos)
            else:
                dist = self.max_range
                hit_pt = ray_to_list[idx]

            ranges.append(round(dist, 3))
            hits.append(hit_pt)

        return {
            "ranges": ranges,
            "min_range": min(ranges) if ranges else self.max_range,
            "num_rays": self.num_rays,
            "fov_deg": math.degrees(self.fov_rad),
            "max_range": self.max_range,
        }
