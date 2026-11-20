# Testing, Verification, and Validation Report

## VR Humanoid Robot Simulator
**Academic Engineering End Semester Examination (ESE) Project**  
**Authors:** Aryan & Vilas  

---

## 1. Test Suite Overview
Automated regression and requirement verification tests were implemented using **pytest**. Tests run without graphic card dependencies using PyBullet's deterministic direct physics engine.

Command to run all tests:
```bash
pytest tests/ -v
```

---

## 2. Formal Requirement Verification Table

| Requirement ID | Test Identifier | Module Tested | Verification Description | Actual Result | Status |
|---|---|---|---|---|---|
| **REQ-01** | `test_joint_discovery` | `tests/test_joints.py` | Verify 13 controllable revolute joints are discovered in URDF with valid limits. | 13/13 joints registered with non-zero torque/velocity limits. | **PASSED** |
| **REQ-02** | `test_joint_limits_enforced` | `tests/test_joints.py` | Verify software clamps target angles outside URDF physical limits. | Exceeded angles clamped strictly to upper and lower limits. | **PASSED** |
| **REQ-03** | `test_individual_joint_actuation` | `tests/test_joints.py` | Set elbow joint target to $45^\circ$, step physics, and measure actual angle. | Joint actuated from $0^\circ \to 20.4^\circ \to 45.0^\circ$ smoothly under motor torque. | **PASSED** |
| **REQ-04** | `test_gravity_and_ground_support` | `tests/test_physics.py` | Drop robot under $-9.81\ \text{m/s}^2$ gravity; verify feet make contact with floor plane. | Torso settles stably at $Z = 0.81\ \text{m}$ above floor. | **PASSED** |
| **REQ-05** | `test_push_force_disturbance` | `tests/test_physics.py` | Apply $350\ \text{N}$ horizontal push to torso; measure displacement and tilt. | Physical displacement detected ($\Delta X > 0.10\ \text{m}$). | **PASSED** |
| **REQ-06** | `test_simulation_reset` | `tests/test_physics.py` | Disturb robot, execute reset command, verify position and joints return to nominal. | Robot restored to $(0.0, 0.0, 0.85)\ \text{m}$ with zero velocity. | **PASSED** |
| **REQ-07** | `test_pid_controller_math` | `tests/test_balance.py` | Validate proportional, integral, and derivative corrections under error perturbation. | Control output matches analytical PID formula. | **PASSED** |
| **REQ-08** | `test_walking_gait_phases` | `tests/test_balance.py` | Activate walking controller for 120 steps; verify full cycle through all 4 gait phases. | All 4 phases observed with synchronized leg and arm movement. | **PASSED** |
| **REQ-09** | `test_obstacle_avoidance_decision_logic` | `tests/test_balance.py` | Feed synthetic raycast distances (clear, blocked-left, blocked-right, trapped). | Avoidance state machine produced exact specified steering decisions. | **PASSED** |
| **REQ-10** | `test_protocol_parsing_valid` | `tests/test_communication.py` | Parse standard JSON command strings and validate fields. | Parsed cleanly into valid command dictionary. | **PASSED** |
| **REQ-11** | `test_protocol_parsing_invalid` | `tests/test_communication.py` | Feed malformed JSON string; verify graceful error handling without crashing. | Returned `(False, None, error_msg)` cleanly. | **PASSED** |
| **REQ-12** | `test_telemetry_builder` | `tests/test_communication.py` | Wrap simulation state dictionary into network telemetry payload. | Validated timestamp, state, balance, links, joints, and sensors. | **PASSED** |
| **REQ-13** | `test_godot_tcp_handshake_and_telemetry` | `tests/test_integration.py` | Spawn live background server, connect simulated Godot client, test walk, push, joint slider, and reset. | Bidirectional command-and-telemetry verified end-to-end. | **PASSED** |

**Summary: 13 Tests Executed, 13 Passed (100% Pass Rate).**

---

## 3. Real Execution Output Log
```text
============================= test session starts =============================
platform win32 -- Python 3.13.9, pytest-8.3.4, pluggy-1.5.0 -- python.exe
cachedir: .pytest_cache
rootdir: C:\ARVR
configfile: pytest.ini
plugins: anyio-4.11.0, hydra-core-1.3.2, langsmith-0.5.0
collecting ... collected 13 items

tests/test_balance.py::test_pid_controller_math PASSED                   [  7%]
tests/test_balance.py::test_walking_gait_phases PASSED                   [ 15%]
tests/test_balance.py::test_obstacle_avoidance_decision_logic PASSED     [ 23%]
tests/test_communication.py::test_protocol_parsing_valid PASSED          [ 30%]
tests/test_communication.py::test_protocol_parsing_invalid PASSED        [ 38%]
tests/test_communication.py::test_telemetry_builder PASSED               [ 46%]
tests/test_integration.py::test_godot_tcp_handshake_and_telemetry PASSED [ 53%]
tests/test_joints.py::test_joint_discovery PASSED                        [ 61%]
tests/test_joints.py::test_joint_limits_enforced PASSED                  [ 69%]
tests/test_joints.py::test_individual_joint_actuation PASSED             [ 76%]
tests/test_physics.py::test_gravity_and_ground_support PASSED            [ 84%]
tests/test_physics.py::test_push_force_disturbance PASSED                [ 92%]
tests/test_physics.py::test_simulation_reset PASSED                      [100%]

============================= 13 passed in 0.92s ==============================
```

---

## 4. ESE Academic Project Defense Checklist

1. [x] **Full decoupling:** Physics engine (PyBullet) is physically distinct from visualizer (Godot).
2. [x] **Zero fake animation:** Robot joint movements are generated by motor position controls and rigid body dynamics.
3. [x] **Bidirectional network protocol:** Non-blocking TCP sockets sending newline-delimited JSON commands and telemetry.
4. [x] **Standalone Desktop deliverable:** Works on standard laptops and desktops using keyboard and mouse without requiring a VR headset.
5. [x] **OpenXR ready:** Automatically initializes VR if a compatible headset is connected; falls back to Desktop mode otherwise.
6. [x] **Blender assets included:** `blender/humanoid.blend` and `blender/environment.blend` present in repo.
7. [x] **Executable batch scripts:** One-click launch (`run_simulator.bat`) ready for examiners.
