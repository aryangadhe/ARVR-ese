"""
TCP Socket Server for Godot-Python bidirectional communication.
Receives commands from the Godot client and broadcasts real-time telemetry.
"""

import socket
import select
import threading
import queue
import time
from typing import Optional, Dict, Any, List
from python.communication.protocol import parse_message, serialize_message, MessageType
from python.communication.telemetry import TelemetryBuilder
from python.simulation import PhysicsSimulation
from python.utils.math_utils import deg_to_rad


class SimulationServer:
    def __init__(
        self,
        simulation: PhysicsSimulation,
        host: str = "127.0.0.1",
        port: int = 9099,
        target_hz: int = 60,
    ):
        self.sim = simulation
        self.host = host
        self.port = port
        self.target_hz = target_hz
        self.running = False

        self.server_socket: Optional[socket.socket] = None
        self.client_socket: Optional[socket.socket] = None
        self.client_address = None

        self.command_queue: queue.Queue = queue.Queue()
        self.send_queue: queue.Queue = queue.Queue()
        self.rx_buffer = ""
        self.lock = threading.Lock()

        # Simulation speed multiplier
        self.speed_multiplier = 1.0

    def start(self):
        """Bind server socket and prepare listening loop."""
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server_socket.bind((self.host, self.port))
        self.server_socket.listen(1)
        self.server_socket.setblocking(False)
        self.running = True
        print(f"[Server] TCP Simulation Server listening on {self.host}:{self.port}")

    def accept_client(self):
        """Check for and accept incoming Godot client connection."""
        if self.client_socket is not None:
            return

        try:
            readable, _, _ = select.select([self.server_socket], [], [], 0.0)
            if readable:
                sock, addr = self.server_socket.accept()
                sock.setblocking(False)
                sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
                with self.lock:
                    self.client_socket = sock
                    self.client_address = addr
                    self.rx_buffer = ""
                print(f"[Server] Connected to Godot client at {addr}")
        except Exception as e:
            pass

    def receive_incoming_data(self):
        """Read data from connected client socket into rx_buffer and extract JSON lines."""
        if self.client_socket is None:
            return

        try:
            readable, _, _ = select.select([self.client_socket], [], [], 0.0)
            if not readable:
                return

            chunk = self.client_socket.recv(4096)
            if not chunk:
                self.disconnect_client("Client disconnected (0 bytes)")
                return

            self.rx_buffer += chunk.decode("utf-8", errors="ignore")
            while "\n" in self.rx_buffer:
                line, self.rx_buffer = self.rx_buffer.split("\n", 1)
                line_stripped = line.strip()
                if not line_stripped:
                    continue
                success, msg, err = parse_message(line_stripped)
                if success and msg is not None:
                    self.command_queue.put(msg)
                elif err:
                    print(f"[Server] Received malformed message: {err}")
        except (ConnectionResetError, ConnectionAbortedError) as e:
            self.disconnect_client(f"Connection reset: {e}")
        except Exception as e:
            print(f"[Server] Error reading from socket: {e}")

    def disconnect_client(self, reason: str = ""):
        with self.lock:
            if self.client_socket:
                try:
                    self.client_socket.close()
                except Exception:
                    pass
                self.client_socket = None
                self.client_address = None
                self.rx_buffer = ""
                print(f"[Server] Client disconnected: {reason}")

    def process_commands(self):
        """Drain command queue and execute actions against simulation and robot."""
        while not self.command_queue.empty():
            cmd = self.command_queue.get_nowait()
            msg_type = cmd.get("type", "")

            try:
                if msg_type == MessageType.COMMAND:
                    action = cmd.get("action", "").lower()
                    if action == "walk":
                        # If robot is fallen, reset upright first before starting gait
                        if self.sim.robot.fall_ctrl.state == self.sim.robot.fall_ctrl.STATE_FALLEN:
                            self.sim.reset_robot()
                        speed = float(cmd.get("speed", 0.4))
                        self.sim.robot.walking_ctrl.start_walking(speed)
                        print(f"[Command] Walk started with speed {speed}")
                    elif action == "stop":
                        self.sim.robot.walking_ctrl.stop_walking()
                        print("[Command] Walk stopped")
                    elif action == "stand":
                        self.sim.robot.walking_ctrl.stop_walking()
                        self.sim.robot.clear_all_manual_joints()
                        if self.sim.robot.fall_ctrl.state == self.sim.robot.fall_ctrl.STATE_FALLEN:
                            self.sim.reset_robot()
                        print("[Command] Returned to standing")
                    elif action == "reset":
                        self.sim.reset_robot()
                        print("[Command] Simulation reset executed")

                elif msg_type == MessageType.JOINT_COMMAND:
                    joint = cmd.get("joint", "")
                    # Support target in degrees or radians
                    if "target_deg" in cmd:
                        rad = deg_to_rad(float(cmd["target_deg"]))
                        self.sim.robot.set_manual_joint(joint, rad)
                    elif "target_angle" in cmd:
                        target = float(cmd["target_angle"])
                        # If value > 3.5, assume degrees
                        if abs(target) > 3.5:
                            rad = deg_to_rad(target)
                        else:
                            rad = target
                        self.sim.robot.set_manual_joint(joint, rad)

                elif msg_type == MessageType.CLEAR_JOINT:
                    joint = cmd.get("joint", "")
                    self.sim.robot.clear_manual_joint(joint)

                elif msg_type == "clear_all_joints":
                    self.sim.robot.clear_all_manual_joints()

                elif msg_type == MessageType.PUSH:
                    mag = float(cmd.get("magnitude", cmd.get("force", 120.0)))
                    direction = cmd.get("direction", "forward")
                    dur = float(cmd.get("duration", 0.15))
                    self.sim.robot.fall_ctrl.apply_push(mag, direction, dur)
                    print(f"[Command] Push applied: {mag}N {direction} for {dur}s")

                elif msg_type == MessageType.FALL_TEST:
                    level = cmd.get("level", "medium").lower()
                    force_map = {"small": 60.0, "medium": 160.0, "strong": 380.0}
                    mag = force_map.get(level, 160.0)
                    self.sim.robot.fall_ctrl.apply_push(mag, "forward", 0.18)
                    print(f"[Command] Fall test triggered: level {level} ({mag}N)")

                elif msg_type == MessageType.SPAWN_OBSTACLE:
                    obs_type = cmd.get("obstacle_type", "cube")
                    pos = cmd.get("position", [1.8, 0.0, 0.4])
                    size = cmd.get("size", None)
                    obs_id = self.sim.spawn_obstacle(obs_type, pos, size)
                    print(f"[Command] Spawned {obs_type} obstacle at {pos} (ID: {obs_id})")

                elif msg_type == MessageType.CLEAR_OBSTACLES:
                    self.sim.clear_all_obstacles()
                    print("[Command] Cleared all obstacles")

                elif msg_type == MessageType.SET_PID:
                    self.sim.robot.balance_ctrl.set_pid_gains(
                        pitch_kp=cmd.get("pitch_kp"),
                        pitch_ki=cmd.get("pitch_ki"),
                        pitch_kd=cmd.get("pitch_kd"),
                        roll_kp=cmd.get("roll_kp"),
                        roll_ki=cmd.get("roll_ki"),
                        roll_kd=cmd.get("roll_kd"),
                    )

                elif msg_type == MessageType.SET_SIMULATION_SPEED:
                    self.speed_multiplier = max(0.1, min(3.0, float(cmd.get("speed_multiplier", 1.0))))

                elif msg_type == MessageType.TOGGLE_AVOIDANCE:
                    self.sim.robot.obstacle_ctrl.enabled = bool(cmd.get("enabled", True))

            except Exception as e:
                print(f"[Server] Error executing command {cmd}: {e}")

    def send_telemetry(self, telemetry_data: Dict[str, Any]):
        """Send telemetry packet to client socket."""
        if self.client_socket is None:
            return

        try:
            packet = TelemetryBuilder.build(telemetry_data)
            data_bytes = serialize_message(packet)

            _, writable, _ = select.select([], [self.client_socket], [], 0.0)
            if writable:
                self.client_socket.sendall(data_bytes)
        except (ConnectionResetError, ConnectionAbortedError):
            self.disconnect_client("Client connection reset during send")
        except Exception as e:
            print(f"[Server] Error sending telemetry: {e}")

    def run_step(self) -> Dict[str, Any]:
        """Perform one network iteration and physics step."""
        self.accept_client()
        self.receive_incoming_data()
        self.process_commands()

        # Advance physics
        sim_data = self.sim.step()

        # Send telemetry to connected Godot client
        self.send_telemetry(sim_data)
        return sim_data

    def run_loop(self):
        """Blocking continuous loop until self.running is False."""
        dt = 1.0 / self.target_hz
        print(f"[Server] Starting simulation loop at {self.target_hz} Hz...")

        while self.running:
            start_t = time.time()
            self.run_step()
            elapsed = time.time() - start_t
            sleep_t = (dt / self.speed_multiplier) - elapsed
            if sleep_t > 0:
                time.sleep(sleep_t)

    def stop(self):
        self.running = False
        self.disconnect_client("Server stopping")
        if self.server_socket:
            try:
                self.server_socket.close()
            except Exception:
                pass
            self.server_socket = None
        print("[Server] Server stopped.")

