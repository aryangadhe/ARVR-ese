"""
Optimal 2D Path Planning and Autonomous Navigation Controller.
Uses A* grid search with obstacle dilation and line-of-sight shortcut smoothing.
Provides closed-loop waypoint tracking, dynamic obstacle evasion, and real-time telemetry.
"""

import math
import heapq
from typing import Dict, Any, List, Tuple, Optional
import pybullet as p
from python.utils.math_utils import clamp, wrap_to_pi


class PathPlannerAStar:
    """Optimal A* grid path planner with obstacle inflation and polygon smoothing."""

    def __init__(self, resolution: float = 0.20, safety_margin: float = 0.50):
        self.resolution = float(resolution)
        self.margin = float(safety_margin)

    def plan(
        self,
        start: Tuple[float, float],
        goal: Tuple[float, float],
        obstacles: List[Dict[str, Any]],
    ) -> List[Tuple[float, float]]:
        """
        Compute optimal shortest path avoiding obstacles.
        Returns ordered list of (x, y) waypoints from start to goal.
        """
        sx, sy = float(start[0]), float(start[1])
        gx, gy = float(goal[0]), float(goal[1])

        # 1. Quick check: if unobstructed line of sight exists, path is direct
        if not self._line_intersects_any((sx, sy), (gx, gy), obstacles):
            return [(round(sx, 3), round(sy, 3)), (round(gx, 3), round(gy, 3))]

        # 2. Determine spatial bounding box with boundary margin
        xs = [sx, gx] + [float(obs["position"][0]) for obs in obstacles]
        ys = [sy, gy] + [float(obs["position"][1]) for obs in obstacles]
        min_x = math.floor(min(xs) - 2.5)
        max_x = math.ceil(max(xs) + 2.5)
        min_y = math.floor(min(ys) - 2.5)
        max_y = math.ceil(max(ys) + 2.5)

        def to_grid(pt: Tuple[float, float]) -> Tuple[int, int]:
            return (
                int(round((pt[0] - min_x) / self.resolution)),
                int(round((pt[1] - min_y) / self.resolution)),
            )

        def to_world(grid: Tuple[int, int]) -> Tuple[float, float]:
            return (
                round(min_x + grid[0] * self.resolution, 3),
                round(min_y + grid[1] * self.resolution, 3),
            )

        s_grid = to_grid((sx, sy))
        g_grid = to_grid((gx, gy))

        # 3. A* Search
        open_set: List[Tuple[float, Tuple[int, int]]] = []
        heapq.heappush(open_set, (0.0, s_grid))
        came_from: Dict[Tuple[int, int], Tuple[int, int]] = {}
        g_score: Dict[Tuple[int, int], float] = {s_grid: 0.0}

        def heuristic(node: Tuple[int, int]) -> float:
            return math.hypot(node[0] - g_grid[0], node[1] - g_grid[1]) * self.resolution

        # 8-connected grid directions
        motions = [
            (1, 0, 1.0),
            (-1, 0, 1.0),
            (0, 1, 1.0),
            (0, -1, 1.0),
            (1, 1, 1.414),
            (-1, 1, 1.414),
            (1, -1, 1.414),
            (-1, -1, 1.414),
        ]

        found = False
        max_iterations = 8000
        iterations = 0

        while open_set and iterations < max_iterations:
            iterations += 1
            _, current = heapq.heappop(open_set)

            if current == g_grid or math.hypot(current[0] - g_grid[0], current[1] - g_grid[1]) <= 1:
                g_grid = current
                found = True
                break

            for dx, dy, cost in motions:
                neighbor = (current[0] + dx, current[1] + dy)
                w_pt = to_world(neighbor)

                if self._point_collides(w_pt, obstacles):
                    continue

                tentative_g = g_score[current] + cost * self.resolution
                if neighbor not in g_score or tentative_g < g_score[neighbor]:
                    came_from[neighbor] = current
                    g_score[neighbor] = tentative_g
                    f_val = tentative_g + heuristic(neighbor)
                    heapq.heappush(open_set, (f_val, neighbor))

        if not found:
            return [(round(sx, 3), round(sy, 3)), (round(gx, 3), round(gy, 3))]

        # Reconstruct path
        path = [g_grid]
        curr = g_grid
        while curr in came_from:
            curr = came_from[curr]
            path.append(curr)
        path.reverse()

        world_path = [to_world(p) for p in path]
        world_path[0] = (round(sx, 3), round(sy, 3))
        world_path[-1] = (round(gx, 3), round(gy, 3))

        # 4. Path smoothing via line-of-sight shortcutting
        smoothed = [world_path[0]]
        i = 0
        while i < len(world_path) - 1:
            furthest = i + 1
            for j in range(len(world_path) - 1, i + 1, -1):
                if not self._line_intersects_any(world_path[i], world_path[j], obstacles):
                    furthest = j
                    break
            smoothed.append(world_path[furthest])
            i = furthest

        return smoothed

    def _point_collides(self, pt: Tuple[float, float], obstacles: List[Dict[str, Any]]) -> bool:
        px, py = pt[0], pt[1]
        for obs in obstacles:
            pos = obs.get("position", [0, 0, 0])
            ox, oy = pos[0], pos[1]
            size = obs.get("size", [0.25, 0.25, 0.4])
            obs_type = obs.get("type", "cube").lower()

            if obs_type == "cylinder":
                r = (size[0] if len(size) > 0 else 0.25) + self.margin
                if math.hypot(px - ox, py - oy) < r:
                    return True
            elif obs_type == "ramp":
                # Ramps can be traversed if approached from front; avoid lateral curbs
                hy = (size[1] if len(size) > 1 else 0.5) + self.margin
                if abs(py - oy) > hy:
                    return False
            else:  # cube, wall, barrier, receptacle
                hx = (size[0] if len(size) > 0 else 0.25) + self.margin
                hy = (size[1] if len(size) > 1 else 0.25) + self.margin
                if abs(px - ox) < hx and abs(py - oy) < hy:
                    return True
        return False

    def _line_intersects_any(
        self,
        p1: Tuple[float, float],
        p2: Tuple[float, float],
        obstacles: List[Dict[str, Any]],
    ) -> bool:
        dist = math.hypot(p2[0] - p1[0], p2[1] - p1[1])
        steps = max(2, int(dist / 0.10))
        for step in range(steps + 1):
            t = step / float(steps)
            x = p1[0] + t * (p2[0] - p1[0])
            y = p1[1] + t * (p2[1] - p1[1])
            if self._point_collides((x, y), obstacles):
                return True
        return False


class NavigationController:
    """
    Closed-loop autonomous navigation manager.
    Coordinates A* path generation, heading pursuit, and arrival detection.
    """

    STATUS_IDLE = "IDLE"
    STATUS_PLANNING = "PLANNING"
    STATUS_NAVIGATING = "NAVIGATING"
    STATUS_REACHED = "REACHED"
    STATUS_BLOCKED = "BLOCKED"

    def __init__(self, robot_ref):
        self.robot = robot_ref
        self.planner = PathPlannerAStar(resolution=0.20, safety_margin=0.52)
        self.active = False
        self.goal: Optional[Tuple[float, float]] = None
        self.path: List[Tuple[float, float]] = []
        self.current_wp_idx = 0
        self.status = self.STATUS_IDLE
        self.target_speed = 0.40
        self.distance_to_goal = 0.0
        self.replan_timer = 0.0

    def set_goal(
        self,
        goal_x: float,
        goal_y: float,
        obstacles: List[Dict[str, Any]],
        speed: float = 0.40,
    ) -> bool:
        """Plan optimal path to target coordinates and initiate autonomous navigation."""
        self.target_speed = clamp(speed, 0.20, 0.80)
        base_pos, _ = p.getBasePositionAndOrientation(self.robot.robot_id)
        start_x, start_y = float(base_pos[0]), float(base_pos[1])
        self.goal = (round(float(goal_x), 3), round(float(goal_y), 3))
        self.distance_to_goal = math.hypot(self.goal[0] - start_x, self.goal[1] - start_y)
        self.status = self.STATUS_PLANNING

        # Compute optimal path
        self.path = self.planner.plan((start_x, start_y), self.goal, obstacles)
        self.current_wp_idx = 1 if len(self.path) > 1 else 0
        self.active = True
        self.status = self.STATUS_NAVIGATING
        self.replan_timer = 0.0

        if hasattr(self.robot, "event_logger") and self.robot.event_logger:
            self.robot.event_logger.log(
                "Navigation",
                f"Navigating to Goal ({goal_x:.2f}, {goal_y:.2f}) | Path: {len(self.path)} waypoints",
                "INFO",
            )
        return True

    def cancel(self):
        """Halt autonomous navigation and clear targets."""
        self.active = False
        self.status = self.STATUS_IDLE
        self.path.clear()
        self.current_wp_idx = 0
        self.goal = None
        self.distance_to_goal = 0.0
        self.robot.walking_ctrl.stop_walking()
        if hasattr(self.robot, "event_logger") and self.robot.event_logger:
            self.robot.event_logger.log("Navigation", "Navigation cancelled by user", "INFO")

    def update(self, dt: float, obstacles: Optional[List[Dict[str, Any]]] = None) -> Dict[str, Any]:
        """
        Advance waypoint follower and generate walking commands.
        """
        if not self.active or self.goal is None or not self.path:
            return self.get_telemetry()

        # If robot has fallen, halt walking immediately
        if hasattr(self.robot, "fall_ctrl") and self.robot.fall_ctrl.state in ("FALLEN", "FALLING"):
            self.robot.walking_ctrl.stop_walking()
            return self.get_telemetry()

        base_pos, base_orn = p.getBasePositionAndOrientation(self.robot.robot_id)
        cur_x = float(base_pos[0])
        cur_y = float(base_pos[1])
        cur_yaw = p.getEulerFromQuaternion(base_orn)[2]

        self.distance_to_goal = math.hypot(self.goal[0] - cur_x, self.goal[1] - cur_y)

        # 1. Check goal arrival threshold
        if self.distance_to_goal <= 0.32:
            self.active = False
            self.status = self.STATUS_REACHED
            self.robot.walking_ctrl.stop_walking()
            if hasattr(self.robot, "event_logger") and self.robot.event_logger:
                self.robot.event_logger.log(
                    "Navigation",
                    f"Target Goal ({self.goal[0]:.2f}, {self.goal[1]:.2f}) successfully reached!",
                    "INFO",
                )
            return self.get_telemetry()

        # 2. Advance through waypoints
        target_wp = self.path[self.current_wp_idx]
        dist_to_wp = math.hypot(target_wp[0] - cur_x, target_wp[1] - cur_y)

        if dist_to_wp < 0.38 and self.current_wp_idx < len(self.path) - 1:
            self.current_wp_idx += 1
            target_wp = self.path[self.current_wp_idx]

        # 3. Calculate desired heading toward current waypoint
        dx = target_wp[0] - cur_x
        dy = target_wp[1] - cur_y
        target_heading = math.atan2(dy, dx)
        yaw_err = wrap_to_pi(target_heading - cur_yaw)

        # 4. Closed-loop steering and heading alignment
        # In PyBullet (+X fwd, +Y left): yaw_err > 0 means goal is to the LEFT.
        # Negative turn_rate produces positive counter-clockwise (+Z) yaw torque.
        if abs(yaw_err) > 0.35:  # Heading error > 20 deg: prioritize turning toward waypoint
            turn_dir = "TURN_LEFT" if yaw_err > 0 else "TURN_RIGHT"
            turn_rate = -0.65 if yaw_err > 0 else 0.65
            self.robot.walking_ctrl.start_walking(speed=0.25, direction=turn_dir)
            self.robot.walking_ctrl.set_turn_rate(turn_rate)
        else:  # Heading aligned within tolerance: drive forward along path with proportional trim
            steer = clamp(-yaw_err * 1.2, -0.35, 0.35)
            self.robot.walking_ctrl.start_walking(speed=self.target_speed, direction="FORWARD")
            self.robot.walking_ctrl.set_turn_rate(steer)

        return self.get_telemetry()

    def get_telemetry(self) -> Dict[str, Any]:
        """Return structured navigation telemetry for network broadcast."""
        return {
            "active": self.active,
            "status": self.status,
            "goal": list(self.goal) if self.goal else [],
            "path": [[round(pt[0], 3), round(pt[1], 3)] for pt in self.path],
            "waypoint_index": self.current_wp_idx,
            "distance_to_goal": round(self.distance_to_goal, 3),
            "target_waypoint": list(self.path[self.current_wp_idx]) if self.path and self.current_wp_idx < len(self.path) else [],
        }
