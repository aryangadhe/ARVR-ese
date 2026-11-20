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
