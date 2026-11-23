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
        left_angle_deg: float = 30.0,
        right_angle_deg: float = -30.0,
    ):
        self.robot_id = robot_id
        self.max_range = float(max_range)
        self.left_angle_rad = math.radians(left_angle_deg)
        self.right_angle_rad = math.radians(right_angle_deg)

    def set_max_range(self, max_range: float):
        """Set distance sensor maximum range in meters."""
        self.max_range = max(0.5, min(10.0, float(max_range)))

    def read(self) -> Dict[str, Any]:
        """
        Cast multi-ray forward sensory fan into the environment.
        Uses a forward wedge (-14° to +14°) to prevent forward blind spots,
        along with left and right flank rays for corridor clearance.
        """
        pos, orn = p.getBasePositionAndOrientation(self.robot_id)
        euler = p.getEulerFromQuaternion(orn)
        yaw = euler[2]

        # Ray origin at lower torso / pelvis height (~0.60m) to reliably intercept obstacles
        sensor_height = pos[2] - 0.22
        origin_x = pos[0] + 0.15 * math.cos(yaw)
        origin_y = pos[1] + 0.15 * math.sin(yaw)
        ray_from = [origin_x, origin_y, sensor_height]

        angles_map = [
            ("front_c", yaw),
            ("front_l", yaw + math.radians(14.0)),
            ("front_r", yaw - math.radians(14.0)),
            ("left", yaw + self.left_angle_rad),
            ("right", yaw + self.right_angle_rad),
        ]

        ray_from_list = []
        ray_to_list = []
        for _, theta in angles_map:
            to_x = origin_x + self.max_range * math.cos(theta)
            to_y = origin_y + self.max_range * math.sin(theta)
            ray_from_list.append(ray_from)
            ray_to_list.append([to_x, to_y, sensor_height])

        results = p.rayTestBatch(ray_from_list, ray_to_list)

        raw_distances = {}
        hit_positions = {}
        has_hits = {}

        for idx, (name, _) in enumerate(angles_map):
            res = results[idx]
            hit_id, _, hit_frac, hit_pos, _ = res
            if hit_id == self.robot_id or (hit_frac < 1.0 and hit_pos[2] < 0.05):
                dist = self.max_range
                h_pos = ray_to_list[idx]
                hit = False
            elif hit_frac < 1.0:
                dist = hit_frac * self.max_range
                h_pos = list(hit_pos)
                hit = True
            else:
                dist = self.max_range
                h_pos = ray_to_list[idx]
                hit = False

            raw_distances[name] = dist
            hit_positions[name] = h_pos
            has_hits[name] = hit

        # Forward reading synthesizes the forward wedge
        f_dist = min(raw_distances["front_c"], raw_distances["front_l"], raw_distances["front_r"])
        l_dist = raw_distances["left"]
        r_dist = raw_distances["right"]

        # Choose the representative hit point for the front ray visualization
        front_key = min(["front_c", "front_l", "front_r"], key=lambda k: raw_distances[k])
        front_hit = has_hits[front_key]
        front_pos = hit_positions[front_key]

        min_dist = min(f_dist, l_dist, r_dist)

        rays_visualization = [
            {
                "name": "front",
                "from": ray_from,
                "to": ray_to_list[0],
                "hit_position": front_pos,
                "has_hit": front_hit,
                "distance": round(f_dist, 3),
            },
            {
                "name": "left",
                "from": ray_from,
                "to": ray_to_list[3],
                "hit_position": hit_positions["left"],
                "has_hit": has_hits["left"],
                "distance": round(l_dist, 3),
            },
            {
                "name": "right",
                "from": ray_from,
                "to": ray_to_list[4],
                "hit_position": hit_positions["right"],
                "has_hit": has_hits["right"],
                "distance": round(r_dist, 3),
            },
        ]

        return {
            "front_distance": round(f_dist, 3),
            "left_distance": round(l_dist, 3),
            "right_distance": round(r_dist, 3),
            "min_distance": round(min_dist, 3),
            "front_hit": front_hit,
            "left_hit": has_hits["left"],
            "right_hit": has_hits["right"],
            "rays": rays_visualization,
        }

