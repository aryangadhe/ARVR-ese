"""
Unit tests for PID balance controller, walking gait generator, and obstacle avoidance.
"""

import pytest
from python.simulation import PhysicsSimulation
from python.utils.pid import PIDController
from python.controllers.walking_controller import WalkingController
from python.controllers.obstacle_avoidance import ObstacleAvoidanceController


def test_pid_controller_math():
    """Verify PID controller produces proportional, integral, and derivative corrections."""
    pid = PIDController(kp=2.0, ki=0.5, kd=0.1, min_output=-10.0, max_output=10.0)
    # First step: error = 1.0, dt = 0.1
    # P = 2.0, I = 0.5 * 0.1 = 0.05, D = 0.0 -> out ~ 2.05
    out1 = pid.update(error=1.0, dt=0.1)
    assert out1 == pytest.approx(2.05, abs=0.01)

    # Second step with same error: integral increases
    out2 = pid.update(error=1.0, dt=0.1)
    assert out2 > out1


def test_walking_gait_phases():
    """Verify walking controller cycles through all 4 phases with non-zero joint targets."""
    wc = WalkingController()
    wc.start_walking(speed=0.6)

    phases_seen = set()
    for step in range(120):
        res = wc.update(dt=1.0 / 60.0)
        assert res["active"] is True
        phases_seen.add(res["phase"])
        assert "left_knee_pitch" in res["targets"]
        assert "right_knee_pitch" in res["targets"]

    # All 4 phases must be reached during a full gait cycle
    assert len(phases_seen) == 4


def test_obstacle_avoidance_decision_logic():
    """Verify reactive obstacle avoidance decisions under different sensor readings."""
    oa = ObstacleAvoidanceController(stop_threshold=0.6, warning_threshold=1.5)

    # 1. Clear ahead
    clear_data = {"front_distance": 3.0, "left_distance": 3.0, "right_distance": 3.0}
    dec1 = oa.evaluate(clear_data)
    assert dec1["action"] == ObstacleAvoidanceController.ACTION_CLEAR
    assert dec1["turn_rate"] == 0.0

    # 2. Obstacle ahead, left path is clearer
    block_front_left_clear = {"front_distance": 0.9, "left_distance": 2.5, "right_distance": 0.8}
    dec2 = oa.evaluate(block_front_left_clear)
    assert dec2["action"] == ObstacleAvoidanceController.ACTION_AVOID_LEFT
    assert dec2["turn_rate"] < 0  # Turn left

    # 3. Obstacle ahead, right path is clearer
    block_front_right_clear = {"front_distance": 0.9, "left_distance": 0.8, "right_distance": 2.5}
    dec3 = oa.evaluate(block_front_right_clear)
    assert dec3["action"] == ObstacleAvoidanceController.ACTION_AVOID_RIGHT
    assert dec3["turn_rate"] > 0  # Turn right

    # 4. Blocked completely
    trapped = {"front_distance": 0.4, "left_distance": 0.4, "right_distance": 0.4}
    dec4 = oa.evaluate(trapped)
    assert dec4["action"] == ObstacleAvoidanceController.ACTION_STOP
    assert dec4["speed_factor"] == 0.0
