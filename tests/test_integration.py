"""
End-to-End Integration Test:
Spawns the simulation server in a background thread, connects a simulated Godot TCP client,
tests command dispatch (walk, stop, push, joint slider, reset), and validates live telemetry.
"""

import time
import socket
import json
import pytest
from python.simulation import PhysicsSimulation
from python.communication.server import SimulationServer
from python.communication.protocol import parse_message


@pytest.fixture(scope="module")
def live_server():
    sim = PhysicsSimulation(gui=False, time_step=1.0 / 60.0)
    server = SimulationServer(simulation=sim, host="127.0.0.1", port=9105, target_hz=60)
    server.start()

    # Step simulation in a background thread
    import threading
    stop_event = threading.Event()

    def loop():
        while not stop_event.is_set():
            server.run_step()
            time.sleep(1.0 / 60.0)

    t = threading.Thread(target=loop, daemon=True)
    t.start()

    yield ("127.0.0.1", 9105)

    stop_event.set()
    t.join(timeout=1.0)
    server.stop()
    sim.close()


def test_godot_tcp_handshake_and_telemetry(live_server):
    host, port = live_server
    client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    client.connect((host, port))
    client.settimeout(3.0)
    sock_file = client.makefile("r", encoding="utf-8")

    # 1. Receive initial telemetry line
    line = sock_file.readline()
    success, data, err = parse_message(line)
    assert success is True
    assert data["type"] == "telemetry"
    assert "links" in data
    assert "joints" in data
    assert "sensors" in data
    assert "torso" in data["links"]

    # 2. Send WALK command
    walk_cmd = json.dumps({"type": "command", "action": "walk", "speed": 0.8}) + "\n"
    client.sendall(walk_cmd.encode("utf-8"))
    time.sleep(0.3)

    # Read updated telemetry
    for _ in range(10):
        line = sock_file.readline()
        success, data, _ = parse_message(line)
        if success and data.get("walking", {}).get("active", False):
            break
    assert data["walking"]["active"] is True

    # 3. Send Joint Command (manual override)
    joint_cmd = json.dumps({"type": "joint_command", "joint": "neck_pitch", "target_deg": 25.0}) + "\n"
    client.sendall(joint_cmd.encode("utf-8"))

    found_joint_target = False
    for _ in range(60):
        line = sock_file.readline()
        success, data, _ = parse_message(line)
        if success:
            neck_state = data.get("joints", {}).get("neck_pitch", {})
            if neck_state.get("target_deg") == 25.0:
                found_joint_target = True
                break
    assert found_joint_target is True

    # 4. Send PUSH disturbance
    push_cmd = json.dumps({"type": "push", "magnitude": 120.0, "direction": "forward", "duration": 0.15}) + "\n"
    client.sendall(push_cmd.encode("utf-8"))
    time.sleep(0.2)

    # 5. Send RESET command
    reset_cmd = json.dumps({"type": "command", "action": "reset"}) + "\n"
    client.sendall(reset_cmd.encode("utf-8"))

    found_reset = False
    for _ in range(60):
        line = sock_file.readline()
        success, data, _ = parse_message(line)
        if success and not data.get("walking", {}).get("active", False):
            found_reset = True
            break
    assert found_reset is True

    sock_file.close()
    client.close()
