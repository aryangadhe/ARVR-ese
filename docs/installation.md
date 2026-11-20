# Installation and User Guide

## VR Humanoid Robot Simulator
**Academic Engineering End Semester Examination (ESE) Project**  
**Authors:** Aryan & Vilas  

---

## 1. System Requirements

| Component | Minimum | Recommended |
|---|---|---|
| Operating System | Windows 10/11 (64-bit), Linux, or macOS | Windows 11 (64-bit) |
| Python | Python 3.10 – 3.13 | Python 3.13 |
| GPU | Dedicated GPU supporting OpenGL 3.3 / Vulkan | NVIDIA RTX 3050 / 4050 or AMD Radeon equivalent |
| RAM | 8 GB | 16 GB |
| Godot Engine | Godot 4.2+ standard (64-bit) | Godot 4.7.2 standard |
| Blender (Optional for modeling) | Blender 4.2 LTS+ | Blender 4.2 LTS |
| VR Headset (Optional) | Any OpenXR compatible PC VR headset (Meta Quest 2/3 via Link, Valve Index, etc.) | Optional (Desktop keyboard & mouse fully supported) |

---

## 2. Installation Steps

### Step 1: Clone or Navigate to the Repository
```bash
git clone https://github.com/aryan-vilas/VR-Humanoid-Robot-Simulator.git
cd VR-Humanoid-Robot-Simulator
```

### Step 2: Install Python Dependencies
Install required packages using pip:
```bash
pip install -r requirements.txt
```
Contents of `requirements.txt`:
```
pybullet>=3.2.5
numpy>=1.24.0
pytest>=7.0.0
```

### Step 3: Verify Tools Installation
Run the following commands to check that Python, PyBullet, and Godot are accessible:
```bash
python -c "import pybullet, numpy; print('PyBullet and NumPy ready!')"
pytest tests/ -v
```

---

## 3. How to Launch the Application

### Option A: One-Click Launch (Recommended for Windows)
Double-click `run_simulator.bat` in the project root directory.
This will:
1. Start the Python physics backend in a separate console window.
2. Wait 2 seconds for server socket binding.
3. Automatically launch the Godot 4.x desktop simulator.

### Option B: Manual CLI Launch (Two Terminals)

**Terminal 1 (Python Backend):**
```bash
python python/main.py
```
*Optional Backend Flags:*
- `--gui`: Launch with native PyBullet 3D debug visualizer.
- `--port 9099`: Specify custom TCP port.
- `--no-server`: Run autonomous physics simulation loop without waiting for Godot.

**Terminal 2 (Godot Desktop Simulator):**
Using the installed Godot executable:
```bash
godot --path godot
```
Or launch Godot, click **Import**, select `godot/project.godot`, and press **Run Project (F5)**.

---

## 4. Controls and Interaction Guide

### Camera Navigation (Desktop Keyboard & Mouse)
- **Orbit Camera:** Click and drag with **Left Mouse Button**.
- **Pan Camera:** Drag with **Right Mouse Button** or **Middle Mouse Button**.
- **Zoom In / Out:** Scroll **Mouse Wheel Up / Down**.
- **Reset View:** Click **Reset Camera** in the top header.

### Robot Controls (Left Dashboard)
- **Start Walking:** Click **▶ START WALKING** to initiate the bipedal 4-phase gait.
- **Stop Walking:** Click **⏹ STOP WALKING** to decelerate and return to standing.
- **Return to Stand:** Click **⚖ RETURN TO STAND** to reset posture.
- **Reset Simulation:** Click **↺ RESET SIMULATION** to restore robot to origin.
- **Disturbance Pushes:** Click **Small (60N)**, **Med (160N)**, or **Fall (350N)** to apply physical external forces.
- **Obstacle Management:** Click **+ Cube**, **+ Cylinder**, or **+ Wall** to dynamically place obstacles in the arena.

### Joint Control Sliders (Right Dashboard)
- Select the **Joints** tab to view live sliders for each of the 13 controllable joints.
- Adjust sliders to override joint angles (head tilt, arm swings, leg flexing).
- Click **Release Manual Joint Overrides** to return motor control back to autonomous balance and walking controllers.

### Optional VR Mode (OpenXR)
- If an OpenXR headset is active and connected before launching the Godot application, the simulator will automatically detect the headset, enable OpenXR, and route views to the HMD.
- If no headset is detected, the simulator automatically uses Desktop Mode without crashing.

