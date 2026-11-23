"""
Unit tests for Optimal 2D Navigation and Obstacle Avoidance Controller.
Verifies A* path planning, obstacle dilation, waypoint following, and arrival detection.
"""

import pytest
import math
import pybullet as p
from python.simulation import PhysicsSimulation
from python.controllers.navigation_controller import PathPlannerAStar, NavigationController


def test_astar_direct_path():
    planner = PathPlannerAStar(resolution=0.20, safety_margin=0.50)
    start = (0.0, 0.0)
    goal = (3.0, 0.0)
    obstacles = []

    path = planner.plan(start, goal, obstacles)
    assert len(path) == 2
    assert path[0] == (0.0, 0.0)
    assert path[-1] == (3.0, 0.0)


def test_astar_obstacle_avoidance_detour():
    planner = PathPlannerAStar(resolution=0.20, safety_margin=0.50)
    start = (0.0, 0.0)
    goal = (4.0, 0.0)
    # Cube obstacle right in the direct path
    obstacles = [
        {"type": "cube", "position": [2.0, 0.0, 0.4], "size": [0.3, 0.3, 0.4]}
    ]

    path = planner.plan(start, goal, obstacles)
    assert len(path) >= 3  # Start, detour waypoint(s), goal
    assert path[0] == (0.0, 0.0)
    assert path[-1] == (4.0, 0.0)

    # Detour must bypass the obstacle laterally (y should deviate from 0)
    max_y_deviation = max(abs(pt[1]) for pt in path)
    assert max_y_deviation >= 0.50, f"Expected lateral detour >= 0.50m, got {max_y_deviation}"


def test_navigation_controller_lifecycle():
    sim = PhysicsSimulation(gui=False)
    try:
        robot = sim.robot
        nav = robot.nav_ctrl
        assert not nav.active
        assert nav.status == NavigationController.STATUS_IDLE

        # Set goal at (2.5, 0.0)
        nav.set_goal(2.5, 0.0, obstacles=[])
        assert nav.active
        assert nav.status == NavigationController.STATUS_NAVIGATING
        assert nav.goal == (2.5, 0.0)

        # Telemetry should reflect active navigation
        telem = nav.get_telemetry()
        assert telem["active"] is True
        assert telem["goal"] == [2.5, 0.0]
        assert len(telem["path"]) >= 2
        assert telem["distance_to_goal"] > 0.0

        # Cancel navigation
        nav.cancel()
        assert not nav.active
        assert nav.status == NavigationController.STATUS_IDLE
        assert not robot.walking_ctrl.is_walking
    finally:
        sim.close()


def test_closed_loop_navigation_arrival():
    sim = PhysicsSimulation(gui=False)
    try:
        robot = sim.robot

        # Set close goal at (0.50, 0.0)
        robot.nav_ctrl.set_goal(0.50, 0.0, obstacles=[], speed=0.45)
        assert robot.nav_ctrl.active

        # Step simulation until arrival or timeout
        for _ in range(300):  # ~5.0 seconds at 60 Hz
            sim.step()
            if robot.nav_ctrl.status == NavigationController.STATUS_REACHED:
                break

        # Robot must reach target within tolerance without falling
        assert robot.nav_ctrl.status == NavigationController.STATUS_REACHED
        assert robot.fall_ctrl.state != "FALLEN"
        final_x = p.getBasePositionAndOrientation(robot.robot_id)[0][0]
        assert final_x >= 0.15, f"Expected forward progress >= 0.15m, got {final_x}"
    finally:
        sim.close()


def test_navigation_steering_direction():
    """Verify navigation commands correct left/right turn direction and rate signs."""
    sim = PhysicsSimulation(gui=False)
    try:
        robot = sim.robot
        nav = robot.nav_ctrl

        # Target to the LEFT (+Y): heading error > 0 -> TURN_LEFT with negative turn_rate
        nav.set_goal(2.0, 1.5, obstacles=[], speed=0.35)
        nav.update(1.0 / 60.0, obstacles=[])
        assert robot.walking_ctrl.direction == "TURN_LEFT"
        assert robot.walking_ctrl.turn_rate < 0, f"Expected negative turn_rate for left turn, got {robot.walking_ctrl.turn_rate}"

        # Target to the RIGHT (-Y): heading error < 0 -> TURN_RIGHT with positive turn_rate
        nav.set_goal(2.0, -1.5, obstacles=[], speed=0.35)
        nav.update(1.0 / 60.0, obstacles=[])
        assert robot.walking_ctrl.direction == "TURN_RIGHT"
        assert robot.walking_ctrl.turn_rate > 0, f"Expected positive turn_rate for right turn, got {robot.walking_ctrl.turn_rate}"
    finally:
        sim.close()
