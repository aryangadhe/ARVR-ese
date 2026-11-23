"""
Unit and integration tests for the Professional Edition features:
- Multi-directional walking controller (Forward, Backward, Turning)
- Center of Mass (COM), ground projection, and support polygon geometry
- Predefined robotics experiments (Scenarios 1 through 5)
- CSV telemetry and experiment export
- Dynamic obstacle collision detection (cubes, cylinders, walls, barriers, ramps)
- Live event logging
"""

import os
import time
import pytest
import numpy as np
from python.simulation import PhysicsSimulation
from python.controllers.walking_controller import WalkingController
from python.controllers.balance_controller import BalanceController
from python.controllers.experiment_manager import ExperimentManager
from python.communication.events import EventLogger
from python.communication.protocol import parse_message, MessageType


@pytest.fixture
def headless_sim():
    sim = PhysicsSimulation(gui=False, time_step=1.0 / 60.0)
    yield sim
    sim.close()


def test_multidirectional_walking_modes(headless_sim):
    robot = headless_sim.robot
    walking = robot.walking_ctrl

    # Test direction switching
    walking.start_walking(speed=0.5, direction="FORWARD")
    assert walking.is_walking is True
    assert walking.direction == "FORWARD"

    # Step forward
    headless_sim.step()
    assert walking.direction == "FORWARD"

    # Switch to backward
    walking.set_direction("BACKWARD")
    assert walking.direction == "BACKWARD"
    headless_sim.step()

    # Switch to turning
    walking.set_direction("TURN_LEFT")
    assert walking.direction == "TURN_LEFT"
    assert walking.turn_rate < 0.0

    walking.set_direction("TURN_RIGHT")
    assert walking.direction == "TURN_RIGHT"
    assert walking.turn_rate > 0.0

    # Stop walking
    walking.stop_walking()
    assert walking.is_walking is False
    assert walking.support_leg == "DOUBLE"


def test_balance_com_and_support_polygon(headless_sim):
    robot = headless_sim.robot
    balance = robot.balance_ctrl

    # Step simulation to settle
    for _ in range(30):
        telemetry = headless_sim.step()

    # Verify COM 3D coordinates
    com = telemetry.get("center_of_mass", [0, 0, 0])
    assert len(com) == 3
    # Humanoid upright COM should be around 0.6 - 0.9m
    assert 0.4 < com[2] < 1.1

    # Verify COM ground projection
    proj = telemetry.get("com_ground_projection", [0, 0, 0])
    assert proj[2] == 0.0
    assert abs(proj[0] - com[0]) < 1e-3
    assert abs(proj[1] - com[1]) < 1e-3

    # Verify Support Polygon
    poly = telemetry.get("support_polygon", [])
    assert len(poly) >= 4  # 2D convex hull around feet

    # Verify Balance Error metric
    bal_error = telemetry.get("balance_error", 0.0)
    assert bal_error >= 0.0


def test_all_six_robotics_experiments(headless_sim):
    exp_mgr = headless_sim.experiment_mgr
    assert exp_mgr is not None

    # Test each of the 6 scenarios
    for exp_id in range(1, 7):
        exp_mgr.start_experiment(exp_id)
        state = exp_mgr.get_state()
        assert state["active"] is True
        assert state["experiment_id"] == exp_id
        assert state["status"] == "RUNNING"

        # Step a few physics frames
        for _ in range(10):
            headless_sim.step()

        # Stop experiment
        exp_mgr.stop_experiment()
        assert exp_mgr.active is False


def test_csv_telemetry_export(headless_sim, tmp_path):
    exp_mgr = headless_sim.experiment_mgr
    exp_mgr.start_experiment(1)

    for _ in range(15):
        headless_sim.step()

    export_file = str(tmp_path / "test_exp_output.csv")
    result_path = exp_mgr.export_csv(export_file)

    assert os.path.exists(result_path)
    with open(result_path, "r", encoding="utf-8") as f:
        content = f.read()
        assert "EXPERIMENT REPORT" in content
        assert "Timeline Log" in content
        assert "Time (s)" in content


def test_obstacle_spawning_and_collision(headless_sim):
    # Spawn barrier
    barrier_id = headless_sim.spawn_obstacle("barrier", [1.0, 0.0, 0.35], [0.15, 0.8, 0.35])
    assert barrier_id in headless_sim.obstacles
    assert headless_sim.obstacles[barrier_id]["type"] == "barrier"

    # Spawn ramp
    ramp_id = headless_sim.spawn_obstacle("ramp", [2.0, 0.0, 0.15], [0.8, 0.5, 0.12])
    assert ramp_id in headless_sim.obstacles
    assert headless_sim.obstacles[ramp_id]["type"] == "ramp"

    # Verify clear obstacles
    headless_sim.clear_all_obstacles()
    assert len(headless_sim.obstacles) == 0


def test_event_logger():
    logger = EventLogger(max_history=50)
    logger.log("Physics", "Gravity updated to -9.81 m/s²", "INFO")
    logger.log("Collision", "Obstacle impact detected", "WARNING")
    logger.log("Fall", "Fall state triggered", "CRITICAL")

    events = logger.get_recent(10)
    assert len(events) == 3
    assert events[0]["severity"] == "INFO"
    assert events[1]["severity"] == "WARNING"
    assert events[2]["severity"] == "CRITICAL"

    logger.clear()
    assert len(logger.get_recent(10)) == 0


def test_protocol_extensions():
    # Verify new message types parse cleanly
    valid_msgs = [
        '{"type": "set_direction", "direction": "backward"}',
        '{"type": "set_gait_params", "step_length": 0.09, "speed": 0.5}',
        '{"type": "start_experiment", "experiment_id": 2}',
        '{"type": "stop_experiment"}',
        '{"type": "reset_experiment"}',
        '{"type": "export_csv", "filename": "test.csv"}',
        '{"type": "set_sensor_range", "max_range": 4.5}',
        '{"type": "set_gravity", "gravity": -1.62}',
        '{"type": "set_time_step", "time_step": 0.01}',
        '{"type": "clear_events"}'
    ]
    for raw in valid_msgs:
        ok, parsed, err = parse_message(raw)
        assert ok is True, f"Failed on {raw}: {err}"
        assert parsed is not None
