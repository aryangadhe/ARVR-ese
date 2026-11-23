import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
import time
from python.simulation import PhysicsSimulation

def test_all():
    sim = PhysicsSimulation(gui=False, time_step=1.0 / 60.0)
    mgr = sim.experiment_mgr

    results = {}
    for sc_id in range(1, 7):
        mgr.start_experiment(sc_id)
        name = mgr.SCENARIO_DEFS[sc_id]["name"]
        print(f"=== Testing Scenario {sc_id}: {name} ===")
        max_dur = mgr.SCENARIO_DEFS[sc_id].get("duration", 20.0)
        max_frames = int((max_dur + 2.0) * 60)

        for frame in range(max_frames):
            sim.step()
            if mgr.status != mgr.STATUS_RUNNING:
                break

        print(f"Result: {mgr.status} in {mgr.elapsed_time:.2f}s | falls={mgr.metrics['falls']} coll={mgr.metrics['collisions']} dist={mgr.metrics['distance']:.2f}m")
        for c in mgr.criteria:
            print(f"  - {c['name']}: {c['met']}")
        print()
        results[sc_id] = {
            "name": name,
            "status": mgr.status,
            "time": mgr.elapsed_time,
            "criteria": [(c["name"], c["met"]) for c in mgr.criteria]
        }

    sim.close()
    return results

if __name__ == "__main__":
    test_all()

