"""
Unit tests for individual joint control, limits, and motor actuation.
"""

import pytest
import pybullet as p
from python.simulation import PhysicsSimulation
from python.utils.math_utils import deg_to_rad, rad_to_deg


@pytest.fixture
def sim():
    s = PhysicsSimulation(gui=False, time_step=1.0 / 60.0)
    yield s
    s.close()


def test_joint_discovery(sim):
    """Verify all 13 joints are discovered and registered with valid limits."""
    jc = sim.robot.joint_ctrl
    assert len(jc.joints) == 13

    expected_joints = [
        "neck_pitch",
        "left_shoulder_pitch",
        "left_elbow_pitch",
        "right_shoulder_pitch",
        "right_elbow_pitch",
        "left_hip_roll",
        "left_hip_pitch",
        "left_knee_pitch",
        "left_ankle_pitch",
        "right_hip_roll",
        "right_hip_pitch",
        "right_knee_pitch",
        "right_ankle_pitch",
    ]
    for j_name in expected_joints:
        assert j_name in jc.joints
        info = jc.joints[j_name]
        assert info["lower_limit"] < info["upper_limit"]
        assert info["max_force"] > 0


def test_joint_limits_enforced(sim):
    """Verify set_target_angle clamps angles exceeding physical limits."""
    jc = sim.robot.joint_ctrl
    # neck_pitch limits are [-0.6, 0.6]
    jc.set_target_angle("neck_pitch", 10.0)
    assert jc.joints["neck_pitch"]["target_angle"] == pytest.approx(0.6)

    jc.set_target_angle("neck_pitch", -10.0)
    assert jc.joints["neck_pitch"]["target_angle"] == pytest.approx(-0.6)


def test_individual_joint_actuation(sim):
    """Verify moving elbow joint changes current angle after physics steps."""
    sim.robot.set_manual_joint("left_elbow_pitch", deg_to_rad(45.0))
    for _ in range(30):
        sim.step()

    states = sim.robot.joint_ctrl.update_states()
    curr_deg = states["left_elbow_pitch"]["current_deg"]
    assert curr_deg > 20.0  # Joint has moved toward target
