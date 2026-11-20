"""
Main Entry Point for the Humanoid Robot Physics Simulator Backend.
Launches the PyBullet physics simulation and the TCP communication server.
"""

import sys
import os
import argparse
import signal
import time

# Ensure project root is in sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from python.simulation import PhysicsSimulation
from python.communication.server import SimulationServer


def main():
    parser = argparse.ArgumentParser(description="VR Humanoid Robot Simulator - Python Physics Backend")
    parser.add_argument("--gui", action="store_true", help="Launch with PyBullet native debug GUI")
    parser.add_argument("--host", type=str, default="127.0.0.1", help="Server listen host (default 127.0.0.1)")
    parser.add_argument("--port", type=int, default=9099, help="Server listen port (default 9099)")
    parser.add_argument("--hz", type=int, default=60, help="Simulation frequency in Hz (default 60)")
    parser.add_argument("--no-server", action="store_true", help="Run standalone physics loop without TCP server")
    args = parser.parse_args()

    print("==================================================================")
    print("   VR HUMANOID ROBOT SIMULATOR - PHYSICS BACKEND")
    print("   Engineering ESE Project | Aryan & Vilas")
    print("==================================================================")
    print(f"Mode: {'PyBullet GUI' if args.gui else 'Headless Direct Backend'}")
    print(f"Target Frequency: {args.hz} Hz")

    sim = PhysicsSimulation(gui=args.gui, time_step=1.0 / args.hz)

    # Spawn default demonstration obstacles
    sim.spawn_obstacle("cube", position=[2.0, 0.0, 0.4], size=[0.25, 0.25, 0.4])
    sim.spawn_obstacle("cylinder", position=[2.5, 1.2, 0.4], size=[0.25, 0.8])
    sim.spawn_obstacle("wall", position=[-2.0, 0.0, 0.5], size=[0.1, 1.5, 0.5])

    server = None
    if not args.no_server:
        server = SimulationServer(simulation=sim, host=args.host, port=args.port, target_hz=args.hz)
        server.start()

    def signal_handler(sig, frame):
        print("\n[Main] Shutdown signal received. Cleaning up...")
        if server:
            server.stop()
        sim.close()
        sys.exit(0)

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    print("\n[Main] Simulator active. Ready for Godot connection or commands.")
    print("Commands accepted via TCP JSON or press Ctrl+C to terminate.\n")

    try:
        if server:
            server.run_loop()
        else:
            # Standalone physics test loop
            print("[Main] Running in standalone headless mode (100 steps demonstration)...")
            for step in range(100):
                telemetry = sim.step()
                if step % 20 == 0:
                    pos = telemetry["position"]
                    state = telemetry["state"]
                    bal = telemetry["balance"]
                    print(f"Step {step:03d} | State: {state} | Balance: {bal} | Pos: ({pos[0]:.2f}, {pos[1]:.2f}, {pos[2]:.2f})")
                time.sleep(1.0 / args.hz)
            print("[Main] Standalone demonstration completed successfully.")
            sim.close()
    except KeyboardInterrupt:
        pass
    finally:
        if server:
            server.stop()
        sim.close()


if __name__ == "__main__":
    main()
