"""
Unit tests for physics dynamics, gravity, collisions, and external push disturbance.
"""

import pytest
import pybullet as p
from python.simulation import PhysicsSimulation


@pytest.fixture
def sim():
    s = PhysicsSimulation(gui=False, time_step=1.0 / 60.0)
    yield s
    s.close()


def test_gravity_and_ground_support(sim):
    """Verify robot rests on ground plane and does not plummet to infinity."""
    for _ in range(60):
        telemetry = sim.step()

    pos = telemetry["position"]
    # Robot torso should settle at approximately 0.75m to 0.85m above ground
    assert 0.65 < pos[2] < 0.90


def test_push_force_disturbance(sim):
    """Verify applying a strong disturbance push causes displacement and tilt."""
    initial_pos = sim.step()["position"]

    # Apply strong push
    sim.robot.fall_ctrl.apply_push(magnitude=350.0, direction="forward", duration=0.2)

    for _ in range(50):
        telemetry = sim.step()

    # Position in X should have shifted forward
    assert telemetry["position"][0] > initial_pos[0] + 0.10


def test_simulation_reset(sim):
    """Verify reset restores robot to initial position."""
    # Move robot with push
    sim.robot.fall_ctrl.apply_push(magnitude=400.0, direction="forward", duration=0.3)
    for _ in range(60):
        sim.step()

    # Reset
    sim.reset_robot()
    for _ in range(5):
        telemetry = sim.step()

    pos = telemetry["position"]
    assert pos[0] == pytest.approx(0.0, abs=0.1)
    assert pos[1] == pytest.approx(0.0, abs=0.1)


def test_stand_robot_in_place(sim):
    """Verify stand_robot_in_place restores robot upright at current location without teleporting to start."""
    # Push robot forward so it falls away from start position (0, 0)
    sim.robot.fall_ctrl.apply_push(magnitude=400.0, direction="forward", duration=0.35)
    for _ in range(70):
        sim.step()

    fall_pos = sim.step()["position"]
    assert fall_pos[0] > 0.20, f"Expected displaced position, got {fall_pos[0]}"
    assert sim.robot.fall_ctrl.state in ("FALLEN", "FALLING")

    # Call stand in place
    sim.stand_robot_in_place()
    for _ in range(10):
        telemetry = sim.step()

    stand_pos = telemetry["position"]
    # Position must remain where it fell, NOT reset to origin (0, 0)
    assert stand_pos[0] >= 0.18, f"Expected to remain at displacement >= 0.18m, got {stand_pos[0]}"
    assert 0.70 < stand_pos[2] < 0.90, f"Expected upright height 0.70-0.90m, got {stand_pos[2]}"
    assert telemetry["state"] in ("STANDING", "BALANCING", "STABLE")

