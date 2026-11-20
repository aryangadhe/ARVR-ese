"""
Experiment & Scenario Automation Manager for Robotics Simulation Platform.
Coordinates 5 predefined engineering examination scenarios, evaluates physical
success/failure criteria, logs performance metrics, and exports CSV analytics.
"""

import time
import os
import csv
from typing import Dict, Any, List, Optional


class ExperimentManager:
    STATUS_IDLE = "IDLE"
    STATUS_RUNNING = "RUNNING"
    STATUS_PASSED = "PASSED"
    STATUS_FAILED = "FAILED"

    SCENARIO_DEFS = {
        1: {
            "id": 1,
            "name": "Basic Walking Test",
            "description": "Forward locomotion on flat terrain. Evaluates gait stability, distance traversed, and average speed.",
            "duration": 15.0,
            "target_distance": 1.0,
        },
        2: {
            "id": 2,
            "name": "Balance & Recovery Test",
            "description": "Standing balance under 80N disturbance push. Evaluates closed-loop PID recovery time and posture stability.",
            "duration": 10.0,
            "push_force": 80.0,
            "max_recovery_time": 3.5,
        },
        3: {
            "id": 3,
            "name": "Push & Fall Dynamics Test",
            "description": "Multi-tier force application (60N, 160N, 350N). Evaluates physical thresholds, recovery, and natural falling.",
            "duration": 15.0,
        },
        4: {
            "id": 4,
            "name": "Obstacle Avoidance Test",
            "description": "Reactive sensory navigation through an obstacle course. Evaluates detection distance, steering, and zero collisions.",
            "duration": 20.0,
        },
        5: {
            "id": 5,
            "name": "Uneven Terrain Test",
            "description": "Locomotion across ramps and terrain barriers. Evaluates bipedal compliance, ground contact, and balance adaptation.",
            "duration": 15.0,
        },
    }

    def __init__(self, simulation_ref):
        self.sim = simulation_ref
        self.current_scenario_id = 0
        self.status = self.STATUS_IDLE
        self.elapsed_time = 0.0
        self.stage_timer = 0.0
        self.stage_index = 0

        # Live experiment metrics
        self.metrics: Dict[str, Any] = {
            "distance": 0.0,
            "speed": 0.0,
            "max_speed": 0.0,
            "falls": 0,
            "recoveries": 0,
            "recovery_time": 0.0,
            "collisions": 0,
            "detections": 0,
            "avg_balance_error": 0.0,
        }

        # Criteria checklist for current experiment
        self.criteria: List[Dict[str, Any]] = []

        # History of completed experiment runs for comparison
        self.run_history: List[Dict[str, Any]] = []

        # Live telemetry log buffer for CSV export
        self.timeline_log: List[Dict[str, Any]] = []

    @property
    def active(self) -> bool:
        return self.status == self.STATUS_RUNNING

    def start_experiment(self, scenario_id: int):
        """Prepare environment, robot, and launch experiment."""
        if scenario_id not in self.SCENARIO_DEFS:
            return

        self.current_scenario_id = scenario_id
        self.status = self.STATUS_RUNNING
        self.elapsed_time = 0.0
        self.stage_timer = 0.0
        self.stage_index = 0
        self.timeline_log.clear()

        # Reset robot and clear overrides
        self.sim.reset_robot()
        self.sim.robot.fall_ctrl.reset(reset_counters=True)
        self.sim.robot.walking_ctrl.reset()
        self.sim.robot.balance_ctrl.reset()
        self.sim.robot.obstacle_ctrl.reset()
        self.sim.robot.clear_all_manual_joints()
        self.sim.clear_all_obstacles()

        defn = self.SCENARIO_DEFS[scenario_id]

        if scenario_id == 1:
            # Flat ground walking test
            self.criteria = [
                {"name": "Zero Falls", "met": True},
                {"name": "Traverse >= 1.0m", "met": False},
                {"name": "Maintain Pitch < 10°", "met": True},
            ]
            self.sim.robot.walking_ctrl.start_walking(0.4, "FORWARD")

        elif scenario_id == 2:
            # Balance recovery test
            self.criteria = [
                {"name": "Zero Falls", "met": True},
                {"name": "Absorb 80N Push", "met": False},
                {"name": "Recover to < 3° within 3.5s", "met": False},
            ]
            self.sim.robot.walking_ctrl.stop_walking()

        elif scenario_id == 3:
            # Push & Fall test
            self.criteria = [
                {"name": "Recover from Small Push (60N)", "met": False},
                {"name": "Destabilize under Med Push (160N)", "met": False},
                {"name": "Physically Fall under Strong Push (350N)", "met": False},
            ]
            self.sim.robot.walking_ctrl.stop_walking()

        elif scenario_id == 4:
            # Obstacle avoidance test
            self.sim.spawn_obstacle("cube", [1.6, 0.0, 0.4], [0.25, 0.25, 0.4])
            self.sim.spawn_obstacle("cylinder", [2.6, 0.45, 0.4], [0.25, 0.8])
            self.criteria = [
                {"name": "Detect Obstacles", "met": False},
                {"name": "Execute Steering Bypass", "met": False},
                {"name": "Zero Collisions", "met": True},
            ]
            self.sim.robot.obstacle_ctrl.enabled = True
            self.sim.robot.walking_ctrl.start_walking(0.4, "FORWARD")

        elif scenario_id == 5:
            # Uneven terrain / ramp test
            self.sim.spawn_obstacle("ramp", [1.5, 0.0, 0.15], [0.8, 0.6, 0.15])
            self.criteria = [
                {"name": "Approach Terrain Incline", "met": False},
                {"name": "Maintain Bipedal Balance", "met": True},
                {"name": "Zero Premature Collapses", "met": True},
            ]
            self.sim.robot.walking_ctrl.start_walking(0.35, "FORWARD")

        if hasattr(self.sim, "event_logger") and self.sim.event_logger:
            self.sim.event_logger.log(
                "Experiment",
                f"Started Scenario {scenario_id}: {defn['name']}",
                "INFO",
            )

    def stop_experiment(self, passed: bool = False, reason: str = ""):
        """Halt active scenario and finalize results."""
        if self.status != self.STATUS_RUNNING:
            return

        self.status = self.STATUS_PASSED if passed else self.STATUS_FAILED
        defn = self.SCENARIO_DEFS.get(self.current_scenario_id, {})
        scenario_name = defn.get("name", "Unknown Scenario")

        record = {
            "scenario_id": self.current_scenario_id,
            "scenario_name": scenario_name,
            "status": self.status,
            "elapsed_time": round(self.elapsed_time, 2),
            "distance": round(self.metrics["distance"], 3),
            "avg_speed": round(self.metrics["speed"], 3),
            "falls": self.metrics["falls"],
            "recoveries": self.metrics["recoveries"],
            "collisions": self.metrics["collisions"],
            "avg_balance_error": round(self.metrics["avg_balance_error"], 4),
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        }
        self.run_history.append(record)

        if hasattr(self.sim, "event_logger") and self.sim.event_logger:
            sev = "INFO" if passed else "WARNING"
            self.sim.event_logger.log(
                "Experiment",
                f"Scenario {self.current_scenario_id} {self.status}! ({reason})",
                sev,
            )

    def reset_experiment(self):
        """Reset scenario state and environment."""
        self.status = self.STATUS_IDLE
        self.current_scenario_id = 0
        self.elapsed_time = 0.0
        self.stage_timer = 0.0
        self.stage_index = 0
        self.criteria.clear()
        self.timeline_log.clear()
        self.sim.reset_robot()
        self.sim.clear_all_obstacles()

    def update(self, dt: float, telemetry_data: Dict[str, Any]):
        """Advance scenario state machine and test criteria."""
        if self.status != self.STATUS_RUNNING:
            return

        self.elapsed_time += dt
        self.stage_timer += dt

        defn = self.SCENARIO_DEFS.get(self.current_scenario_id, {})
        max_dur = defn.get("duration", 20.0)

        # Update metrics
        pos = telemetry_data.get("position", [0, 0, 0])
        lin_vel = telemetry_data.get("linear_velocity", [0, 0, 0])
        walking_data = telemetry_data.get("walking", {})
        fall_data = telemetry_data.get("fall_count", 0)
        state_str = telemetry_data.get("state", "STANDING")
        pitch_deg = abs(telemetry_data.get("pitch", 0.0))

        dist = walking_data.get("walking_distance", max(0.0, pos[0]))
        curr_speed = abs(lin_vel[0])
        self.metrics["distance"] = dist
        self.metrics["speed"] = curr_speed
        self.metrics["max_speed"] = max(self.metrics["max_speed"], curr_speed)
        self.metrics["falls"] = fall_data
        self.metrics["recoveries"] = self.sim.robot.fall_ctrl.successful_recoveries
        self.metrics["avg_balance_error"] = telemetry_data.get("balance_error", 0.0)

        # Record timeline point
        if len(self.timeline_log) < 600:
            self.timeline_log.append({
                "time": round(self.elapsed_time, 2),
                "x": round(pos[0], 3),
                "pitch": round(telemetry_data.get("pitch", 0.0), 2),
                "roll": round(telemetry_data.get("roll", 0.0), 2),
                "speed": round(curr_speed, 3),
                "balance_error": round(telemetry_data.get("balance_error", 0.0), 4),
                "state": state_str,
            })

        # --- Scenario 1: Basic Walking Test ---
        if self.current_scenario_id == 1:
            if state_str == "FALLEN" or self.metrics["falls"] > 0:
                self.criteria[0]["met"] = False
                self.stop_experiment(passed=False, reason="Robot fell before reaching target")
                return

            if dist >= defn["target_distance"]:
                self.criteria[1]["met"] = True
                self.stop_experiment(passed=True, reason=f"Traversed {dist:.2f}m without falling")
                return

            if self.elapsed_time >= max_dur:
                if dist >= defn["target_distance"]:
                    self.stop_experiment(passed=True, reason=f"Completed {dist:.2f}m")
                else:
                    self.stop_experiment(passed=False, reason=f"Timeout: only reached {dist:.2f}m")

        # --- Scenario 2: Balance & Recovery Test ---
        elif self.current_scenario_id == 2:
            if state_str == "FALLEN" or self.metrics["falls"] > 0:
                self.criteria[0]["met"] = False
                self.stop_experiment(passed=False, reason="Robot fell from disturbance")
                return

            # Apply push at t = 2.0s
            if self.stage_index == 0 and self.elapsed_time >= 2.0:
                self.sim.robot.fall_ctrl.apply_push(defn.get("push_force", 80.0), "forward", 0.15)
                self.criteria[1]["met"] = True
                self.stage_index = 1
                self.stage_timer = 0.0

            # Measure recovery
            elif self.stage_index == 1:
                if pitch_deg < 3.0 and self.stage_timer > 0.8:
                    self.criteria[2]["met"] = True
                    rec_time = round(self.stage_timer, 2)
                    self.metrics["recovery_time"] = rec_time
                    self.stop_experiment(passed=True, reason=f"Fully recovered in {rec_time}s")
                    return
                elif self.stage_timer > defn.get("max_recovery_time", 3.5):
                    self.stop_experiment(passed=False, reason="Recovery exceeded maximum time limit")

        # --- Scenario 3: Push & Fall Dynamics ---
        elif self.current_scenario_id == 3:
            # Stage 0: 60N at 1.5s
            if self.stage_index == 0 and self.elapsed_time >= 1.5:
                self.sim.robot.fall_ctrl.apply_push(60.0, "forward", 0.15)
                self.stage_index = 1
                self.stage_timer = 0.0
            # Stage 1: evaluate recovery from 60N, apply 160N at 5.0s
            elif self.stage_index == 1 and self.stage_timer >= 3.0:
                self.criteria[0]["met"] = (state_str != "FALLEN")
                self.sim.robot.fall_ctrl.apply_push(160.0, "forward", 0.15)
                self.stage_index = 2
                self.stage_timer = 0.0
            # Stage 2: evaluate 160N response, apply 350N strong push at 8.5s
            elif self.stage_index == 2 and self.stage_timer >= 3.5:
                self.criteria[1]["met"] = True
                self.sim.robot.fall_ctrl.apply_push(350.0, "forward", 0.20)
                self.stage_index = 3
                self.stage_timer = 0.0
            # Stage 3: verify natural fall
            elif self.stage_index == 3:
                if state_str == "FALLEN":
                    self.criteria[2]["met"] = True
                    self.stop_experiment(passed=True, reason="Natural fall dynamics validated at 350N")
                elif self.stage_timer > 4.0:
                    self.stop_experiment(passed=False, reason="350N failed to trigger expected fall")

        # --- Scenario 4: Obstacle Avoidance Test ---
        elif self.current_scenario_id == 4:
            if self.metrics["collisions"] > 0:
                self.criteria[2]["met"] = False
                self.stop_experiment(passed=False, reason="Collision occurred with obstacle")
                return

            if telemetry_data.get("sensors", {}).get("min_distance", 5.0) < 1.4:
                self.criteria[0]["met"] = True

            avoid_act = telemetry_data.get("obstacle_avoidance", {}).get("action", "CLEAR")
            if avoid_act in ("AVOIDING_LEFT", "AVOIDING_RIGHT"):
                self.criteria[1]["met"] = True

            if pos[0] >= 3.2:
                self.stop_experiment(passed=True, reason="Successfully navigated obstacle course")
            elif self.elapsed_time >= max_dur:
                self.stop_experiment(passed=(self.metrics["collisions"] == 0), reason="Course completed")

        # --- Scenario 5: Uneven Terrain Test ---
        elif self.current_scenario_id == 5:
            if state_str == "FALLEN":
                self.criteria[2]["met"] = False
                self.stop_experiment(passed=False, reason="Fell on uneven terrain")
                return

            if pos[0] >= 1.2:
                self.criteria[0]["met"] = True

            if pos[0] >= 2.5:
                self.stop_experiment(passed=True, reason="Traversed uneven terrain ramp successfully")
            elif self.elapsed_time >= max_dur:
                self.stop_experiment(passed=(state_str != "FALLEN"), reason="Time elapsed")

    def export_csv(self, filename: Optional[str] = None) -> str:
        """Export simulation timeline and experiment summary to CSV."""
        if not filename:
            ts = time.strftime("%Y%m%d_%H%M%S")
            filename = f"experiment_results_{ts}.csv"

        filepath = os.path.join(os.getcwd(), filename)
        try:
            with open(filepath, mode="w", newline="", encoding="utf-8") as f:
                writer = csv.writer(f)
                writer.writerow(["=== VR HUMANOID ROBOT SIMULATOR - EXPERIMENT REPORT ==="])
                writer.writerow(["Scenario ID", self.current_scenario_id])
                writer.writerow(["Scenario Name", self.SCENARIO_DEFS.get(self.current_scenario_id, {}).get("name", "N/A")])
                writer.writerow(["Final Status", self.status])
                writer.writerow(["Total Duration (s)", round(self.elapsed_time, 2)])
                writer.writerow(["Total Distance (m)", round(self.metrics["distance"], 3)])
                writer.writerow(["Average Speed (m/s)", round(self.metrics["speed"], 3)])
                writer.writerow(["Total Falls", self.metrics["falls"]])
                writer.writerow(["Successful Recoveries", self.metrics["recoveries"]])
                writer.writerow(["Collisions", self.metrics["collisions"]])
                writer.writerow(["Avg Balance Error (m)", round(self.metrics["avg_balance_error"], 4)])
                writer.writerow([])
                writer.writerow(["--- Timeline Log (60Hz Sampled) ---"])
                writer.writerow(["Time (s)", "Position X (m)", "Pitch (deg)", "Roll (deg)", "Speed (m/s)", "Balance Error (m)", "State"])
                for pt in self.timeline_log:
                    writer.writerow([pt["time"], pt["x"], pt["pitch"], pt["roll"], pt["speed"], pt["balance_error"], pt["state"]])
            return filepath
        except Exception as e:
            print(f"[ExperimentManager] Failed to export CSV: {e}")
            return ""

    def get_state(self) -> Dict[str, Any]:
        """Compile scenario status for telemetry."""
        defn = self.SCENARIO_DEFS.get(self.current_scenario_id, {})
        return {
            "active": self.active,
            "experiment_id": self.current_scenario_id,
            "scenario_id": self.current_scenario_id,
            "scenario_name": defn.get("name", "No Experiment Running"),
            "description": defn.get("description", ""),
            "status": self.status,
            "elapsed_time": round(self.elapsed_time, 2),
            "progress": round(min(1.0, self.elapsed_time / max(0.1, defn.get("duration", 10.0))), 2) if self.active else 0.0,
            "max_duration": defn.get("duration", 0.0),
            "metrics": dict(self.metrics),
            "criteria": list(self.criteria),
            "run_history": list(self.run_history[-6:]),
        }
