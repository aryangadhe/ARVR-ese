"""
Math and kinematics utilities for VR Humanoid Robot Simulator.
Handles rotations, Center of Mass (COM), support polygon checks, and filtering.
"""

import math
from typing import List, Tuple, Optional


def clamp(val: float, min_val: float, max_val: float) -> float:
    """Clamp a value within [min_val, max_val]."""
    return max(min_val, min(val, max_val))


def rad_to_deg(rad: float) -> float:
    """Convert radians to degrees."""
    return rad * (180.0 / math.pi)


def deg_to_rad(deg: float) -> float:
    """Convert degrees to radians."""
    return deg * (math.pi / 180.0)


def normalize_angle(angle: float) -> float:
    """Wrap angle to [-pi, pi]."""
    while angle > math.pi:
        angle -= 2.0 * math.pi
    while angle < -math.pi:
        angle += 2.0 * math.pi
    return angle


# Alias for angle wrapping
wrap_to_pi = normalize_angle


def compute_center_of_mass(
    masses: List[float], positions: List[Tuple[float, float, float]]
) -> Tuple[float, float, float]:
    """
    Compute total Center of Mass (COM) given link masses and their 3D world positions.
    COM = sum(m_i * p_i) / sum(m_i)
    """
    total_mass = sum(masses)
    if total_mass <= 1e-6:
        return (0.0, 0.0, 0.0)

    com_x = sum(m * p[0] for m, p in zip(masses, positions)) / total_mass
    com_y = sum(m * p[1] for m, p in zip(masses, positions)) / total_mass
    com_z = sum(m * p[2] for m, p in zip(masses, positions)) / total_mass
    return (com_x, com_y, com_z)


def is_point_in_polygon_2d(px: float, py: float, polygon: List[Tuple[float, float]]) -> bool:
    """
    Check if 2D point (px, py) lies inside a convex or simple polygon using ray casting.
    """
    n = len(polygon)
    if n < 3:
        return False

    inside = False
    p1x, p1y = polygon[0]
    for i in range(n + 1):
        p2x, p2y = polygon[i % n]
        if py > min(p1y, p2y):
            if py <= max(p1y, p2y):
                if px <= max(p1x, p2x):
                    if p1y != p2y:
                        xinters = (py - p1y) * (p2x - p1x) / (p2y - p1y) + p1x
                    if p1x == p2x or px <= xinters:
                        inside = not inside
        p1x, p1y = p2x, p2y
    return inside


def compute_support_polygon(
    left_foot_pos: Tuple[float, float, float],
    right_foot_pos: Tuple[float, float, float],
    foot_length: float = 0.20,
    foot_width: float = 0.11,
) -> List[Tuple[float, float]]:
    """
    Approximate bounding box polygon in XY floor plane spanned by both feet.
    """
    hl = foot_length / 2.0
    hw = foot_width / 2.0

    min_x = min(left_foot_pos[0], right_foot_pos[0]) - hl
    max_x = max(left_foot_pos[0], right_foot_pos[0]) + hl
    min_y = min(left_foot_pos[1], right_foot_pos[1]) - hw
    max_y = max(left_foot_pos[1], right_foot_pos[1]) + hw

    # Clockwise polygon vertices
    return [
        (min_x, min_y),
        (min_x, max_y),
        (max_x, max_y),
        (max_x, min_y),
    ]


class LowPassFilter:
    """First-order low pass filter for smoothing noisy sensor data."""

    def __init__(self, alpha: float = 0.2, initial_value: float = 0.0):
        self.alpha = clamp(alpha, 0.0, 1.0)
        self.value = initial_value
        self.initialized = False

    def update(self, new_val: float) -> float:
        if not self.initialized:
            self.value = new_val
            self.initialized = True
        else:
            self.value = self.alpha * new_val + (1.0 - self.alpha) * self.value
        return self.value

    def reset(self, val: float = 0.0):
        self.value = val
        self.initialized = False

