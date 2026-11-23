extends Control
class_name UIController

@export var network_client: Node
@export var camera_controller: Node3D
@export var robot_visualizer: Node3D

# --- Top Navigation Bar ---
var status_connection: Label
var status_physics: Label
var status_xr: Label
var opt_camera: OptionButton
var tab_buttons: Array[Button] = []
var tab_panels: Array[Control] = []
var current_tab_idx: int = 0

# --- Collapsible Panels in Tab 1 (Simulation) ---
var left_panel: Control
var right_panel: Control
var bottom_panel: Control
var btn_toggle_left: Button
var btn_toggle_right: Button
var btn_toggle_bottom: Button
var left_collapsed: bool = false
var right_collapsed: bool = false
var bottom_collapsed: bool = false

# --- Simulation Tab Status Labels ---
var lbl_sim_state: Label
var lbl_sim_balance: Label
var lbl_sim_fall_count: Label
var lbl_sim_rpy: Label
var lbl_sim_pos: Label
var lbl_sim_walk_phase: Label
var lbl_sim_sensors: Label
var lbl_sim_avoidance: Label
var lbl_sim_collisions: Label

# --- Robot Control Tab ---
var lbl_ctrl_dir: Label
var lbl_ctrl_speed: Label
var lbl_ctrl_dist: Label
var lbl_ctrl_support: Label
var prog_ctrl_gait: ProgressBar
var sld_ctrl_speed: HSlider
var sld_ctrl_steplen: HSlider
var sld_ctrl_stepdur: HSlider
var lbl_ctrl_speed_val: Label
var lbl_ctrl_steplen_val: Label
var lbl_ctrl_stepdur_val: Label

# --- Balance Monitoring Tab ---
var lbl_bal_roll: Label
var lbl_bal_pitch: Label
var lbl_bal_yaw: Label
var lbl_bal_com: Label
var lbl_bal_com_proj: Label
var lbl_bal_error: Label
var lbl_bal_support_status: Label
var lbl_bal_foot_left: Label
var lbl_bal_foot_right: Label
var graph_balance: Control
var sld_pid_p_kp: HSlider
var sld_pid_p_ki: HSlider
var sld_pid_p_kd: HSlider
var sld_pid_r_kp: HSlider
var sld_pid_r_ki: HSlider
var sld_pid_r_kd: HSlider
var lbl_pid_p_kp: Label
var lbl_pid_p_ki: Label
var lbl_pid_p_kd: Label
var lbl_pid_r_kp: Label
var lbl_pid_r_ki: Label
var lbl_pid_r_kd: Label

# --- Sensors Tab ---
var lbl_sens_front: Label
var lbl_sens_left: Label
var lbl_sens_right: Label
var lbl_sens_min: Label
var lbl_sens_status_banner: Label
var sld_sens_range: HSlider
var lbl_sens_range_val: Label
var chk_sens_avoid: CheckBox
var lbl_lidar_summary: Label

# --- Analytics Tab ---
var lbl_ana_distance: Label
var lbl_ana_avg_speed: Label
var lbl_ana_max_tilt: Label
var lbl_ana_falls: Label
var lbl_ana_collisions: Label
var lbl_ana_stability: Label
var graph_analytics: Control

# --- Experiments Tab ---
var opt_exp_scenario: OptionButton
var lbl_exp_title: Label
var lbl_exp_desc: Label
var lbl_exp_status: Label
var prog_exp: ProgressBar
var chk_exp_c1: CheckBox
var chk_exp_c2: CheckBox
var chk_exp_c3: CheckBox
var chk_exp_c4: CheckBox
var chk_exp_c5: CheckBox
var lbl_exp_summary: Label

# --- Settings Tab ---
var sld_set_gravity: HSlider
var lbl_set_gravity_val: Label
var sld_set_timestep: HSlider
var lbl_set_timestep_val: Label
var opt_set_simspeed: OptionButton

# --- Bottom Event Log ---
var event_log_list: ItemList
var last_event_count: int = 0

# --- Joint Sliders & Highlighting ---
var joint_ui_map: Dictionary = {}
var joint_filter: String = "ALL"
var updating_from_telemetry: bool = false
var max_tilt_recorded: float = 0.0

const JOINT_DEFS = {
	"neck_pitch": {"min": -34.0, "max": 34.0, "default": 0.0, "title": "Neck Pitch", "category": "HEAD", "link": "head"},
	"left_shoulder_pitch": {"min": -100.0, "max": 100.0, "default": 0.0, "title": "L Shoulder Pitch", "category": "ARMS", "link": "left_upper_arm"},
	"left_elbow_pitch": {"min": 0.0, "max": 125.0, "default": 20.0, "title": "L Elbow Pitch", "category": "ARMS", "link": "left_forearm"},
	"right_shoulder_pitch": {"min": -100.0, "max": 100.0, "default": 0.0, "title": "R Shoulder Pitch", "category": "ARMS", "link": "right_upper_arm"},
	"right_elbow_pitch": {"min": 0.0, "max": 125.0, "default": 20.0, "title": "R Elbow Pitch", "category": "ARMS", "link": "right_forearm"},
	"left_hip_roll": {"min": -20.0, "max": 20.0, "default": 0.0, "title": "L Hip Roll", "category": "LEGS", "link": "left_thigh"},
	"left_hip_pitch": {"min": -68.0, "max": 68.0, "default": -6.8, "title": "L Hip Pitch", "category": "LEGS", "link": "left_thigh"},
	"left_knee_pitch": {"min": 0.0, "max": 125.0, "default": 13.7, "title": "L Knee Pitch", "category": "LEGS", "link": "left_shin"},
	"left_ankle_pitch": {"min": -40.0, "max": 40.0, "default": -6.8, "title": "L Ankle Pitch", "category": "LEGS", "link": "left_foot"},
	"right_hip_roll": {"min": -20.0, "max": 20.0, "default": 0.0, "title": "R Hip Roll", "category": "LEGS", "link": "right_thigh"},
	"right_hip_pitch": {"min": -68.0, "max": 68.0, "default": -6.8, "title": "R Hip Pitch", "category": "LEGS", "link": "right_thigh"},
	"right_knee_pitch": {"min": 0.0, "max": 125.0, "default": 13.7, "title": "R Knee Pitch", "category": "LEGS", "link": "right_shin"},
	"right_ankle_pitch": {"min": -40.0, "max": 40.0, "default": -6.8, "title": "R Ankle Pitch", "category": "LEGS", "link": "right_foot"},
}

const EXPERIMENT_INFO = {
	1: {
		"title": "Experiment 1: Basic Walking Dynamics",
		"desc": "Executes 5.0m forward locomotion at nominal 0.45 m/s speed.\nVerifies gait phase progression, lateral roll stability, and continuous foot contact symmetry.",
		"c1": "Target distance >= 5.0m",
		"c2": "Roll tilt deviation < 8.0°",
		"c3": "Zero fall incidents",
		"c4": "Gait frequency steady"
	},
	2: {
		"title": "Experiment 2: Balance Recovery Under Push",
		"desc": "Applies an impulsive 120N forward disturbance force.\nMeasures settling time for torso pitch recovery and hip PID restoring torque effectiveness.",
		"c1": "Torso recovery within 2.5s",
		"c2": "Residual pitch error < 3.0°",
		"c3": "Zero fall incidents",
		"c4": "PID damping effective"
	},
	3: {
		"title": "Experiment 3: Push & Fall Dynamics",
		"desc": "Applies incrementally escalating disturbance pulses (60N -> 160N -> 350N).\nLogs impact kinematics, joint collapse angles, and post-fall ground contact points.",
		"c1": "Incremental push applied",
		"c2": "Fall threshold correctly detected",
		"c3": "Ground impact logged",
		"c4": "Safe motor torque cutoff"
	},
	4: {
		"title": "Experiment 4: Obstacle Avoidance Course",
		"desc": "Navigates toward target while detecting dynamic obstacles with 3-ray sensors.\nEvaluates reactive steering, path clearance margin, and collision prevention.",
		"c1": "Obstacle detected > 1.2m",
		"c2": "Steering maneuver initiated",
		"c3": "Zero obstacle collisions",
		"c4": "Path clearance > 0.4m"
	},
	5: {
		"title": "Experiment 5: Uneven Terrain & Incline Test",
		"desc": "Tests gait stability over an inclined 8° test ramp obstacle.\nAnalyzes ankle compliance, center of mass ground projection shift, and balance error.",
		"c1": "Ramp obstacle mounted",
		"c2": "COM inside support polygon",
		"c3": "Zero fall incidents",
		"c4": "Ankle pitch compensation active"
	},
	6: {
		"title": "Experiment 6: Pick & Place Manipulation Test",
		"desc": "Autonomous approach, upper-limb arm reach, physical object grasp, 0.15m vertical lift, payload transport, and precision placement into destination receptacle.",
		"c1": "Approach Pick Station",
		"c2": "Arm Trajectory & Grasp",
		"c3": "Vertical Lift Clearance",
		"c4": "Transport to Place Zone",
		"c5": "Precision Place & Release"
	}
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resolve_references()
	_setup_top_bar()
	_setup_collapsible_panels()
	_setup_robot_control_tab()
	_setup_balance_tab()
	_setup_sensors_tab()
	_setup_analytics_tab()
	_setup_experiments_tab()
	_setup_settings_tab()
	_setup_bottom_event_log()
	_build_joint_sliders()
	_connect_network()
	_switch_tab(0)

func _resolve_references() -> void:
	if not network_client:
		network_client = get_node_or_null("../NetworkClient")
	if not camera_controller:
		camera_controller = get_node_or_null("../CameraController")
	if not robot_visualizer:
		robot_visualizer = get_node_or_null("../RobotVisualizer")

	status_connection = find_child("LblConnection", true, false) as Label
	status_physics = find_child("LblPhysicsStatus", true, false) as Label
	status_xr = find_child("LblXR", true, false) as Label
	opt_camera = find_child("OptCamera", true, false) as OptionButton

	left_panel = find_child("LeftPanel", true, false) as Control
	right_panel = find_child("RightPanel", true, false) as Control
	bottom_panel = find_child("BottomPanel", true, false) as Control
	btn_toggle_left = find_child("BtnToggleLeft", true, false) as Button
	btn_toggle_right = find_child("BtnToggleRight", true, false) as Button
	btn_toggle_bottom = find_child("BtnToggleBottom", true, false) as Button

	# Tab panels
	var tab_names = [
		"TabPanel_Sim", "TabPanel_Control", "TabPanel_Balance",
		"TabPanel_Sensors", "TabPanel_Analytics", "TabPanel_Experiments",
		"TabPanel_Settings"
	]
	tab_panels.clear()
	for t_name in tab_names:
		var p = find_child(t_name, true, false) as Control
		if p:
			tab_panels.append(p)

	# Sim Status Labels
	lbl_sim_state = find_child("LblSimState", true, false) as Label
	lbl_sim_balance = find_child("LblSimBalance", true, false) as Label
	lbl_sim_fall_count = find_child("LblSimFallCount", true, false) as Label
	lbl_sim_rpy = find_child("LblSimRPY", true, false) as Label
	lbl_sim_pos = find_child("LblSimPos", true, false) as Label
	lbl_sim_walk_phase = find_child("LblSimWalkPhase", true, false) as Label
	lbl_sim_sensors = find_child("LblSimSensors", true, false) as Label
	lbl_sim_avoidance = find_child("LblSimAvoidance", true, false) as Label
	lbl_sim_collisions = find_child("LblSimCollisions", true, false) as Label

	# Robot Control
	lbl_ctrl_dir = find_child("LblCtrlDir", true, false) as Label
	lbl_ctrl_speed = find_child("LblCtrlSpeed", true, false) as Label
	lbl_ctrl_dist = find_child("LblCtrlDist", true, false) as Label
	lbl_ctrl_support = find_child("LblCtrlSupport", true, false) as Label
	prog_ctrl_gait = find_child("ProgCtrlGait", true, false) as ProgressBar
	sld_ctrl_speed = find_child("SldCtrlSpeed", true, false) as HSlider
	sld_ctrl_steplen = find_child("SldCtrlStepLen", true, false) as HSlider
	sld_ctrl_stepdur = find_child("SldCtrlStepDur", true, false) as HSlider
	lbl_ctrl_speed_val = find_child("LblCtrlSpeedVal", true, false) as Label
	lbl_ctrl_steplen_val = find_child("LblCtrlStepLenVal", true, false) as Label
	lbl_ctrl_stepdur_val = find_child("LblCtrlStepDurVal", true, false) as Label

	# Balance
	lbl_bal_roll = find_child("LblBalRoll", true, false) as Label
	lbl_bal_pitch = find_child("LblBalPitch", true, false) as Label
	lbl_bal_yaw = find_child("LblBalYaw", true, false) as Label
	lbl_bal_com = find_child("LblBalCOM", true, false) as Label
	lbl_bal_com_proj = find_child("LblBalCOMProj", true, false) as Label
	lbl_bal_error = find_child("LblBalError", true, false) as Label
	lbl_bal_support_status = find_child("LblBalSupportStatus", true, false) as Label
	lbl_bal_foot_left = find_child("LblBalFootLeft", true, false) as Label
	lbl_bal_foot_right = find_child("LblBalFootRight", true, false) as Label
	graph_balance = find_child("GraphBalance", true, false) as Control

	sld_pid_p_kp = find_child("SldPidPKp", true, false) as HSlider
	sld_pid_p_ki = find_child("SldPidPKi", true, false) as HSlider
	sld_pid_p_kd = find_child("SldPidPKd", true, false) as HSlider
	sld_pid_r_kp = find_child("SldPidRKp", true, false) as HSlider
	sld_pid_r_ki = find_child("SldPidRKi", true, false) as HSlider
	sld_pid_r_kd = find_child("SldPidRKd", true, false) as HSlider
	lbl_pid_p_kp = find_child("LblPidPKpVal", true, false) as Label
	lbl_pid_p_ki = find_child("LblPidPKiVal", true, false) as Label
	lbl_pid_p_kd = find_child("LblPidPKdVal", true, false) as Label
	lbl_pid_r_kp = find_child("LblPidRKpVal", true, false) as Label
	lbl_pid_r_ki = find_child("LblPidRKiVal", true, false) as Label
	lbl_pid_r_kd = find_child("LblPidRKdVal", true, false) as Label

	# Sensors
	lbl_sens_front = find_child("LblSensFront", true, false) as Label
	lbl_sens_left = find_child("LblSensLeft", true, false) as Label
	lbl_sens_right = find_child("LblSensRight", true, false) as Label
	lbl_sens_min = find_child("LblSensMin", true, false) as Label
	lbl_sens_status_banner = find_child("LblSensStatusBanner", true, false) as Label
	sld_sens_range = find_child("SldSensRange", true, false) as HSlider
	lbl_sens_range_val = find_child("LblSensRangeVal", true, false) as Label
	chk_sens_avoid = find_child("ChkSensAvoid", true, false) as CheckBox
	lbl_lidar_summary = find_child("LblLidarSummary", true, false) as Label

	# Analytics
	lbl_ana_distance = find_child("LblAnaDist", true, false) as Label
	lbl_ana_avg_speed = find_child("LblAnaAvgSpeed", true, false) as Label
	lbl_ana_max_tilt = find_child("LblAnaMaxTilt", true, false) as Label
	lbl_ana_falls = find_child("LblAnaFalls", true, false) as Label
	lbl_ana_collisions = find_child("LblAnaCollisions", true, false) as Label
	lbl_ana_stability = find_child("LblAnaStability", true, false) as Label
	graph_analytics = find_child("GraphAnalytics", true, false) as Control

	# Experiments
	opt_exp_scenario = find_child("OptExpScenario", true, false) as OptionButton
	lbl_exp_title = find_child("LblExpTitle", true, false) as Label
	lbl_exp_desc = find_child("LblExpDesc", true, false) as Label
	lbl_exp_status = find_child("LblExpStatus", true, false) as Label
	prog_exp = find_child("ProgExp", true, false) as ProgressBar
	chk_exp_c1 = find_child("ChkExpC1", true, false) as CheckBox
	chk_exp_c2 = find_child("ChkExpC2", true, false) as CheckBox
	chk_exp_c3 = find_child("ChkExpC3", true, false) as CheckBox
	chk_exp_c4 = find_child("ChkExpC4", true, false) as CheckBox
	chk_exp_c5 = find_child("ChkExpC5", true, false) as CheckBox
	lbl_exp_summary = find_child("LblExpSummary", true, false) as Label

	# Settings
	sld_set_gravity = find_child("SldSetGravity", true, false) as HSlider
	lbl_set_gravity_val = find_child("LblSetGravityVal", true, false) as Label
	sld_set_timestep = find_child("SldSetTimestep", true, false) as HSlider
	lbl_set_timestep_val = find_child("LblSetTimestepVal", true, false) as Label
	opt_set_simspeed = find_child("OptSetSimSpeed", true, false) as OptionButton

	# Event Log
	event_log_list = find_child("EventLogList", true, false) as ItemList

func _setup_top_bar() -> void:
	var tab_btn_names = [
		"BtnTabSim", "BtnTabControl", "BtnTabBalance",
		"BtnTabSensors", "BtnTabAnalytics", "BtnTabExperiments",
		"BtnTabSettings"
	]
	tab_buttons.clear()
	for i in range(tab_btn_names.size()):
		var b_name = tab_btn_names[i]
		var btn = find_child(b_name, true, false) as Button
		if btn:
			var idx = i
			btn.pressed.connect(func(): _switch_tab(idx))
			tab_buttons.append(btn)

	if opt_camera:
		opt_camera.clear()
		opt_camera.add_item("Orbit View")
		opt_camera.add_item("Follow Cam")
		opt_camera.add_item("Front View")
		opt_camera.add_item("Side View")
		opt_camera.add_item("Top-Down")
		opt_camera.item_selected.connect(func(index):
			if not camera_controller:
				return
			match index:
				0: camera_controller.set_mode("ORBIT")
				1: camera_controller.set_mode("FOLLOW")
				2: camera_controller.set_mode("FRONT")
				3: camera_controller.set_mode("SIDE")
				4: camera_controller.set_mode("TOP")
		)

	_bind_button("BtnResetCam", func():
		if camera_controller:
			camera_controller.reset_camera()
			if opt_camera:
				opt_camera.selected = 0
	)

func _switch_tab(idx: int) -> void:
	current_tab_idx = idx
	for i in range(tab_panels.size()):
		tab_panels[i].visible = (i == idx)

	for i in range(tab_buttons.size()):
		if i == idx:
			tab_buttons[i].add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
		else:
			tab_buttons[i].add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))

func _setup_collapsible_panels() -> void:
	if btn_toggle_left and left_panel:
		btn_toggle_left.pressed.connect(func():
			left_collapsed = not left_collapsed
			left_panel.visible = not left_collapsed
			btn_toggle_left.text = "▶" if left_collapsed else "◀"
		)

	if btn_toggle_right and right_panel:
		btn_toggle_right.pressed.connect(func():
			right_collapsed = not right_collapsed
			right_panel.visible = not right_collapsed
			btn_toggle_right.text = "◀" if right_collapsed else "▶"
		)

	if btn_toggle_bottom and bottom_panel:
		btn_toggle_bottom.pressed.connect(func():
			bottom_collapsed = not bottom_collapsed
			bottom_panel.visible = not bottom_collapsed
			btn_toggle_bottom.text = "▲" if bottom_collapsed else "▼"
		)

	# Quick Sim Controls
	_bind_button("BtnSimWalk", func():
		_reset_sliders_to_defaults()
		if network_client: network_client.send_command("walk")
	)
	_bind_button("BtnSimStop", func():
		if network_client:
			network_client.send_command("stop")
			network_client.cancel_navigation()
	)
	_bind_button("BtnSimStand", func():
		_reset_sliders_to_defaults()
		if network_client: network_client.send_command("stand")
	)
	_bind_button("BtnSimReset", func():
		_reset_sliders_to_defaults()
		if network_client:
			network_client.send_command("reset")
			network_client.cancel_navigation()
	)

	# Quick Arena Navigation D-Pad buttons on main simulation tab
	_bind_button("BtnQuickFwd", func(): if network_client: network_client.set_direction("forward"))
	_bind_button("BtnQuickBack", func(): if network_client: network_client.set_direction("backward"))
	_bind_button("BtnQuickLeft", func(): if network_client: network_client.set_direction("turn_left"))
	_bind_button("BtnQuickRight", func(): if network_client: network_client.set_direction("turn_right"))

	# Goal Navigation section with click-to-floor guidance & preset destination buttons
	var btn_fwd: Button = find_child("BtnQuickFwd", true, false) as Button
	if btn_fwd:
		var parent_vbox = btn_fwd.get_parent().get_parent()
		if parent_vbox is VBoxContainer:
			var lbl_goal_title = Label.new()
			lbl_goal_title.text = "🎯 GOAL NAVIGATION [A* OPTIMAL]"
			lbl_goal_title.add_theme_font_size_override("font_size", 11)
			lbl_goal_title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
			parent_vbox.add_child(lbl_goal_title)

			var lbl_hint = Label.new()
			lbl_hint.text = "💡 Left-Click on 3D floor (or Shift+Click)"
			lbl_hint.add_theme_font_size_override("font_size", 10)
			lbl_hint.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
			parent_vbox.add_child(lbl_hint)

			var hbox_presets_1 = HBoxContainer.new()
			var btn_goal_1 = Button.new()
			btn_goal_1.text = "Goal [2.5, 1.0]"
			btn_goal_1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_goal_1.pressed.connect(func(): if network_client: network_client.navigate_to_goal(2.5, 1.0))
			hbox_presets_1.add_child(btn_goal_1)

			var btn_goal_2 = Button.new()
			btn_goal_2.text = "Goal [3.5, -1.0]"
			btn_goal_2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_goal_2.pressed.connect(func(): if network_client: network_client.navigate_to_goal(3.5, -1.0))
			hbox_presets_1.add_child(btn_goal_2)
			parent_vbox.add_child(hbox_presets_1)

			var hbox_presets_2 = HBoxContainer.new()
			var btn_goal_3 = Button.new()
			btn_goal_3.text = "Origin [0, 0]"
			btn_goal_3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_goal_3.pressed.connect(func(): if network_client: network_client.navigate_to_goal(0.0, 0.0))
			hbox_presets_2.add_child(btn_goal_3)

			var btn_cancel_nav = Button.new()
			btn_cancel_nav.text = "❌ Cancel"
			btn_cancel_nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_cancel_nav.pressed.connect(func(): if network_client: network_client.cancel_navigation())
			hbox_presets_2.add_child(btn_cancel_nav)
			parent_vbox.add_child(hbox_presets_2)

	# Disturbance buttons
	_bind_button("BtnSimSmallPush", func(): if network_client: network_client.send_push(60.0, "forward", 0.15))
	_bind_button("BtnSimMedPush", func(): if network_client: network_client.send_push(160.0, "forward", 0.15))
	_bind_button("BtnSimStrongPush", func(): if network_client: network_client.send_push(350.0, "forward", 0.20))

	# Obstacle buttons
	_bind_button("BtnSimSpawnCube", func(): if network_client: network_client.spawn_obstacle("cube", [1.8, 0.0, 0.4], [0.25, 0.25, 0.4]))
	_bind_button("BtnSimSpawnCyl", func(): if network_client: network_client.spawn_obstacle("cylinder", [2.2, 0.4, 0.4], [0.25, 0.8]))
	_bind_button("BtnSimSpawnWall", func(): if network_client: network_client.spawn_obstacle("wall", [-2.0, 0.0, 0.5], [0.1, 1.5, 0.5]))
	_bind_button("BtnSimSpawnBarrier", func(): if network_client: network_client.spawn_obstacle("barrier", [2.5, -0.4, 0.35], [0.15, 0.8, 0.35]))
	_bind_button("BtnSimSpawnRamp", func(): if network_client: network_client.spawn_obstacle("ramp", [3.2, 0.0, 0.2], [0.8, 0.5, 0.12]))
	_bind_button("BtnSimClearObs", func(): if network_client: network_client.clear_obstacles())

	var chk_av = find_child("ChkSimAvoidance", true, false) as CheckBox
	if chk_av and network_client:
		chk_av.toggled.connect(func(toggled): network_client.toggle_avoidance(toggled))

func _setup_robot_control_tab() -> void:
	_bind_button("BtnDirForward", func(): if network_client: network_client.set_direction("forward"))
	_bind_button("BtnDirBackward", func(): if network_client: network_client.set_direction("backward"))
	_bind_button("BtnDirLeft", func(): if network_client: network_client.set_direction("turn_left"))
	_bind_button("BtnDirRight", func(): if network_client: network_client.set_direction("turn_right"))
	_bind_button("BtnDirStop", func(): if network_client: network_client.send_command("stop"))

	if sld_ctrl_speed:
		sld_ctrl_speed.value_changed.connect(func(val):
			if lbl_ctrl_speed_val: lbl_ctrl_speed_val.text = "%.2f m/s" % val
			_send_current_gait_params()
		)
	if sld_ctrl_steplen:
		sld_ctrl_steplen.value_changed.connect(func(val):
			if lbl_ctrl_steplen_val: lbl_ctrl_steplen_val.text = "%.3f rad" % val
			_send_current_gait_params()
		)
	if sld_ctrl_stepdur:
		sld_ctrl_stepdur.value_changed.connect(func(val):
			if lbl_ctrl_stepdur_val: lbl_ctrl_stepdur_val.text = "%.2f s" % val
			_send_current_gait_params()
		)

func _send_current_gait_params() -> void:
	if not network_client:
		return
	var spd = sld_ctrl_speed.value if sld_ctrl_speed else 0.45
	var slen = sld_ctrl_steplen.value if sld_ctrl_steplen else 0.08
	var sdur = sld_ctrl_stepdur.value if sld_ctrl_stepdur else 0.45
	network_client.set_gait_params(slen, sdur, spd)

func _setup_balance_tab() -> void:
	var setup_pid_slider = func(sld: HSlider, lbl: Label, param_key: String):
		if sld:
			sld.value_changed.connect(func(val):
				if lbl: lbl.text = "%.2f" % val
				_send_pid_gains()
			)

	setup_pid_slider.call(sld_pid_p_kp, lbl_pid_p_kp, "pitch_kp")
	setup_pid_slider.call(sld_pid_p_ki, lbl_pid_p_ki, "pitch_ki")
	setup_pid_slider.call(sld_pid_p_kd, lbl_pid_p_kd, "pitch_kd")
	setup_pid_slider.call(sld_pid_r_kp, lbl_pid_r_kp, "roll_kp")
	setup_pid_slider.call(sld_pid_r_ki, lbl_pid_r_ki, "roll_ki")
	setup_pid_slider.call(sld_pid_r_kd, lbl_pid_r_kd, "roll_kd")

	_bind_button("BtnPidResetDefaults", func():
		if sld_pid_p_kp: sld_pid_p_kp.value = 6.0
		if sld_pid_p_ki: sld_pid_p_ki.value = 0.5
		if sld_pid_p_kd: sld_pid_p_kd.value = 0.4
		if sld_pid_r_kp: sld_pid_r_kp.value = 5.0
		if sld_pid_r_ki: sld_pid_r_ki.value = 0.3
		if sld_pid_r_kd: sld_pid_r_kd.value = 0.3
		_send_pid_gains()
	)

func _send_pid_gains() -> void:
	if not network_client:
		return
	network_client.set_pid({
		"pitch_kp": sld_pid_p_kp.value if sld_pid_p_kp else 6.0,
		"pitch_ki": sld_pid_p_ki.value if sld_pid_p_ki else 0.5,
		"pitch_kd": sld_pid_p_kd.value if sld_pid_p_kd else 0.4,
		"roll_kp": sld_pid_r_kp.value if sld_pid_r_kp else 5.0,
		"roll_ki": sld_pid_r_ki.value if sld_pid_r_ki else 0.3,
		"roll_kd": sld_pid_r_kd.value if sld_pid_r_kd else 0.3,
	})

func _setup_sensors_tab() -> void:
	if sld_sens_range:
		sld_sens_range.value_changed.connect(func(val):
			if lbl_sens_range_val: lbl_sens_range_val.text = "%.1fm" % val
			if network_client: network_client.set_sensor_range(val)
		)

	if chk_sens_avoid:
		chk_sens_avoid.toggled.connect(func(toggled):
			if network_client: network_client.toggle_avoidance(toggled)
		)

func _setup_analytics_tab() -> void:
	_bind_button("BtnExportCsv", func():
		if network_client:
			network_client.export_csv("telemetry_export.csv")
	)

func _setup_experiments_tab() -> void:
	if opt_exp_scenario:
		opt_exp_scenario.clear()
		for id in range(1, 7):
			opt_exp_scenario.add_item(EXPERIMENT_INFO[id]["title"], id)
		opt_exp_scenario.item_selected.connect(_on_experiment_selected)
		_on_experiment_selected(0)

	_bind_button("BtnExpStart", func():
		if network_client:
			var id = opt_exp_scenario.selected + 1 if opt_exp_scenario else 1
			network_client.start_experiment(id)
	)
	_bind_button("BtnExpStop", func():
		if network_client: network_client.stop_experiment()
	)
	_bind_button("BtnExpReset", func():
		if network_client: network_client.reset_experiment()
	)
	_bind_button("BtnExpExportCsv", func():
		if network_client:
			var id = opt_exp_scenario.selected + 1 if opt_exp_scenario else 1
			network_client.export_csv("experiment_%d_results.csv" % id)
	)

func _on_experiment_selected(index: int) -> void:
	var exp_id = index + 1
	if exp_id in EXPERIMENT_INFO:
		var info = EXPERIMENT_INFO[exp_id]
		if lbl_exp_title: lbl_exp_title.text = info["title"]
		if lbl_exp_desc: lbl_exp_desc.text = info["desc"]
		if chk_exp_c1: chk_exp_c1.text = info["c1"]; chk_exp_c1.button_pressed = false
		if chk_exp_c2: chk_exp_c2.text = info["c2"]; chk_exp_c2.button_pressed = false
		if chk_exp_c3: chk_exp_c3.text = info["c3"]; chk_exp_c3.button_pressed = false
		if chk_exp_c4: chk_exp_c4.text = info["c4"]; chk_exp_c4.button_pressed = false
		if chk_exp_c5:
			if "c5" in info:
				chk_exp_c5.text = info["c5"]
				chk_exp_c5.visible = true
				chk_exp_c5.button_pressed = false
			else:
				chk_exp_c5.visible = false

		# Frame the workstation with optimal camera perspective for manipulation
		if exp_id == 6 and camera_controller:
			camera_controller.target_yaw = deg_to_rad(-50.0)
			camera_controller.target_pitch = deg_to_rad(-18.0)
			camera_controller.target_distance = 2.2
			camera_controller.transitioning = true

func _setup_settings_tab() -> void:
	if sld_set_gravity:
		sld_set_gravity.value_changed.connect(func(val):
			if lbl_set_gravity_val: lbl_set_gravity_val.text = "%.2f m/s²" % val
			if network_client: network_client.set_gravity(val)
		)

	_bind_button("BtnGravEarth", func(): if sld_set_gravity: sld_set_gravity.value = -9.81)
	_bind_button("BtnGravMoon", func(): if sld_set_gravity: sld_set_gravity.value = -1.62)
	_bind_button("BtnGravMars", func(): if sld_set_gravity: sld_set_gravity.value = -3.71)
	_bind_button("BtnGravZero", func(): if sld_set_gravity: sld_set_gravity.value = 0.0)

	if sld_set_timestep:
		sld_set_timestep.value_changed.connect(func(val):
			var dt = 1.0 / val
			if lbl_set_timestep_val: lbl_set_timestep_val.text = "%d Hz (%.4fs)" % [round(val), dt]
			if network_client: network_client.set_time_step(dt)
		)

	if opt_set_simspeed:
		opt_set_simspeed.clear()
		opt_set_simspeed.add_item("0.25x (Slow-Motion)")
		opt_set_simspeed.add_item("0.50x")
		opt_set_simspeed.add_item("1.00x (Real-Time)")
		opt_set_simspeed.add_item("2.00x (Fast-Forward)")
		opt_set_simspeed.selected = 2
		opt_set_simspeed.item_selected.connect(func(idx):
			var mult = 1.0
			match idx:
				0: mult = 0.25
				1: mult = 0.50
				2: mult = 1.00
				3: mult = 2.00
			if network_client: network_client.set_simulation_speed(mult)
		)

func _setup_bottom_event_log() -> void:
	_bind_button("BtnClearLog", func():
		if event_log_list:
			event_log_list.clear()
		last_event_count = 0
		if network_client:
			network_client.clear_events()
	)

func _build_joint_sliders() -> void:
	var joint_container = find_child("JointsVBox", true, false) as VBoxContainer
	if not joint_container:
		return

	for cat in ["ALL", "HEAD", "ARMS", "LEGS"]:
		var btn = find_child("BtnFilter_" + cat, true, false) as Button
		if btn:
			var filter_name = cat
			btn.pressed.connect(func(): _filter_joints(filter_name))

	_bind_button("BtnResetAllJoints", func():
		_reset_sliders_to_defaults()
		if network_client: network_client.clear_all_joints()
		if robot_visualizer: robot_visualizer.highlight_link("")
	)

	updating_from_telemetry = true
	for j_name in JOINT_DEFS:
		var def = JOINT_DEFS[j_name]
		var row = VBoxContainer.new()
		row.name = "Row_" + j_name
		row.add_theme_constant_override("separation", 2)

		var header_hbox = HBoxContainer.new()
		var title_lbl = Label.new()
		title_lbl.text = def["title"]
		title_lbl.custom_minimum_size = Vector2(130, 0)
		title_lbl.add_theme_font_size_override("font_size", 12)
		header_hbox.add_child(title_lbl)

		var val_lbl = Label.new()
		val_lbl.text = "0.0°"
		val_lbl.add_theme_font_size_override("font_size", 12)
		header_hbox.add_child(val_lbl)

		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_hbox.add_child(spacer)

		var btn_hl = Button.new()
		btn_hl.text = "◎"
		btn_hl.tooltip_text = "Highlight joint in 3D viewport"
		var link_name = def["link"]
		btn_hl.pressed.connect(func():
			if robot_visualizer:
				robot_visualizer.highlight_link(link_name)
		)
		header_hbox.add_child(btn_hl)

		var btn_rst = Button.new()
		btn_rst.text = "↺"
		btn_rst.tooltip_text = "Reset this joint override"
		var jn = j_name
		btn_rst.pressed.connect(func():
			if network_client: network_client.clear_joint(jn)
			if jn in joint_ui_map:
				joint_ui_map[jn]["slider"].value = JOINT_DEFS[jn]["default"]
		)
		header_hbox.add_child(btn_rst)
		row.add_child(header_hbox)

		var slider = HSlider.new()
		slider.min_value = def["min"]
		slider.max_value = def["max"]
		slider.step = 0.5
		slider.value = def["default"]
		slider.custom_minimum_size = Vector2(220, 18)

		var curr_joint = j_name
		slider.value_changed.connect(func(new_val):
			val_lbl.text = "%.1f°" % new_val
			if not updating_from_telemetry and network_client and slider.has_focus():
				network_client.send_joint_command(curr_joint, new_val)
		)
		row.add_child(slider)
		joint_container.add_child(row)

		joint_ui_map[j_name] = {
			"row": row,
			"slider": slider,
			"val_lbl": val_lbl,
			"category": def["category"]
		}
	updating_from_telemetry = false

func _filter_joints(cat: String) -> void:
	joint_filter = cat
	for j_name in joint_ui_map:
		var item = joint_ui_map[j_name]
		var row: Control = item["row"]
		row.visible = (cat == "ALL" or item["category"] == cat)

func _reset_sliders_to_defaults() -> void:
	updating_from_telemetry = true
	for j_name in JOINT_DEFS:
		if j_name in joint_ui_map:
			var sld: HSlider = joint_ui_map[j_name]["slider"]
			var val_lbl: Label = joint_ui_map[j_name]["val_lbl"]
			var def_val = JOINT_DEFS[j_name]["default"]
			sld.value = def_val
			val_lbl.text = "Cur: %+.1f° (Set: %+.1f°)" % [def_val, def_val]
	updating_from_telemetry = false

func _bind_button(node_name: String, callback: Callable) -> void:
	var btn: Button = find_child(node_name, true, false) as Button
	if btn:
		btn.pressed.connect(callback)

func _connect_network() -> void:
	if network_client:
		network_client.connected_to_server.connect(_on_network_connected)
		network_client.disconnected_from_server.connect(_on_network_disconnected)
		network_client.telemetry_received.connect(_on_telemetry_received)

func _on_network_connected() -> void:
	if status_connection:
		status_connection.text = "● BACKEND CONNECTED"
		status_connection.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
	if network_client:
		network_client.send_command("stand")

func _on_network_disconnected() -> void:
	if status_connection:
		status_connection.text = "○ DISCONNECTED (RETRYING...)"
		status_connection.add_theme_color_override("font_color", Color(0.9, 0.3, 0.2))

func _on_telemetry_received(data: Dictionary) -> void:
	var state_str = data.get("state", "UNKNOWN")
	var balance_str = data.get("balance", "UNKNOWN")
	var fall_count = data.get("fall_count", 0)
	var roll = data.get("roll", 0.0)
	var pitch = data.get("pitch", 0.0)
	var yaw = data.get("yaw", 0.0)
	var pos = data.get("position", [0, 0, 0])
	var walking = data.get("walking", {})
	var sensors = data.get("sensors", {})
	var avoidance = data.get("obstacle_avoidance", {})
	var physics = data.get("physics", {})
	var exp_data = data.get("experiment", {})
	var events = data.get("events", [])
	var collisions = data.get("collision_count", 0)
	var bal_error = data.get("balance_error", 0.0)

	var tilt_max_now = max(abs(roll), abs(pitch))
	if tilt_max_now > max_tilt_recorded:
		max_tilt_recorded = tilt_max_now

	# 1. Header status badges
	if status_physics and physics.size() > 0:
		status_physics.text = "Physics: %s Hz | dt: %.3fs | G: %.1f m/s²" % [
			str(physics.get("frequency_hz", 60.0)),
			physics.get("time_step", 0.016),
			physics.get("gravity", -9.81)
		]

	# 2. Simulation Tab Status Card
	if lbl_sim_state:
		lbl_sim_state.text = "State: " + state_str
		if state_str in ["STANDING", "WALKING"]:
			lbl_sim_state.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
		elif state_str in ["UNSTABLE", "BALANCING", "FALLING"]:
			lbl_sim_state.add_theme_color_override("font_color", Color(0.95, 0.7, 0.1))
		else:
			lbl_sim_state.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))

	if lbl_sim_balance: lbl_sim_balance.text = "Balance: " + balance_str
	if lbl_sim_fall_count: lbl_sim_fall_count.text = "Fall Incidents: %d" % int(fall_count)
	if lbl_sim_rpy: lbl_sim_rpy.text = "R: %+.1f° | P: %+.1f° | Y: %+.1f°" % [roll, pitch, yaw]
	if lbl_sim_pos: lbl_sim_pos.text = "Pos: (%.2f, %.2f, %.2f)m" % [pos[0], pos[1], pos[2]]
	if lbl_sim_walk_phase:
		var act = walking.get("active", false)
		var phase = walking.get("phase", "STAND")
		var dir_str = walking.get("direction", "FORWARD")
		lbl_sim_walk_phase.text = "Gait: " + (dir_str + " (" + phase + ")" if act else "STAND / IDLE")
	if lbl_sim_sensors:
		lbl_sim_sensors.text = "Sensors: F: %.2fm | L: %.2fm | R: %.2fm" % [
			sensors.get("front_distance", 0.0),
			sensors.get("left_distance", 0.0),
			sensors.get("right_distance", 0.0)
		]
	var nav = data.get("navigation", {})
	if lbl_sim_avoidance:
		if nav.get("active", false):
			var g = nav.get("goal", [0, 0])
			var d = nav.get("distance_to_goal", 0.0)
			lbl_sim_avoidance.text = "Goal: (%.1f, %.1f) | Dist: %.2fm" % [g[0], g[1], d]
			lbl_sim_avoidance.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
		elif nav.get("status", "") == "REACHED":
			var g = nav.get("goal", [0, 0])
			lbl_sim_avoidance.text = "Goal REACHED! (%.1f, %.1f)" % [g[0], g[1]]
			lbl_sim_avoidance.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		else:
			lbl_sim_avoidance.text = "Avoidance: " + avoidance.get("action", "CLEAR")
			lbl_sim_avoidance.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	if lbl_sim_collisions: lbl_sim_collisions.text = "Collisions: %d" % collisions

	# 3. Robot Control Tab
	if lbl_ctrl_dir:
		if nav.get("active", false):
			var g = nav.get("goal", [0, 0])
			var wp_idx = nav.get("waypoint_index", 0) + 1
			var wp_total = max(1, nav.get("path", []).size())
			lbl_ctrl_dir.text = "Nav -> (%.1f, %.1f) | WP %d/%d" % [g[0], g[1], wp_idx, wp_total]
		else:
			lbl_ctrl_dir.text = "Direction: " + walking.get("direction", "FORWARD")
	if lbl_ctrl_speed: lbl_ctrl_speed.text = "Speed: %.2f m/s" % walking.get("instantaneous_speed", 0.0)
	if lbl_ctrl_dist: lbl_ctrl_dist.text = "Distance: %.2f m" % walking.get("walking_distance", 0.0)
	if lbl_ctrl_support: lbl_ctrl_support.text = "Support: " + walking.get("support_leg", "DOUBLE")
	if prog_ctrl_gait:
		prog_ctrl_gait.value = clamp(walking.get("gait_progress", 0.0) * 100.0, 0.0, 100.0)

	# 4. Balance Monitoring Tab
	if lbl_bal_roll:
		lbl_bal_roll.text = "Roll: %+.1f°" % roll
		lbl_bal_roll.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4) if abs(roll) < 6.0 else (Color(0.95, 0.7, 0.1) if abs(roll) < 15.0 else Color(1.0, 0.25, 0.25)))
	if lbl_bal_pitch:
		lbl_bal_pitch.text = "Pitch: %+.1f°" % pitch
		lbl_bal_pitch.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4) if abs(pitch) < 6.0 else (Color(0.95, 0.7, 0.1) if abs(pitch) < 15.0 else Color(1.0, 0.25, 0.25)))
	if lbl_bal_yaw: lbl_bal_yaw.text = "Yaw: %+.1f°" % yaw

	var com = data.get("center_of_mass", [0, 0, 0])
	var com_proj = data.get("com_ground_projection", [0, 0, 0])
	if lbl_bal_com: lbl_bal_com.text = "COM (3D): (%.2f, %.2f, %.2f)m" % [com[0], com[1], com[2]]
	if lbl_bal_com_proj: lbl_bal_com_proj.text = "Ground Proj: (%.2f, %.2f)m" % [com_proj[0], com_proj[1]]
	if lbl_bal_error: lbl_bal_error.text = "Balance Error: %.3f m" % bal_error

	var foot_contacts = data.get("foot_contacts", {})
	if lbl_bal_foot_left:
		var l_g = foot_contacts.get("left_grounded", true)
		lbl_bal_foot_left.text = "Left Foot: " + ("GROUNDED" if l_g else "IN AIR")
		lbl_bal_foot_left.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4) if l_g else Color(0.5, 0.7, 1.0))
	if lbl_bal_foot_right:
		var r_g = foot_contacts.get("right_grounded", true)
		lbl_bal_foot_right.text = "Right Foot: " + ("GROUNDED" if r_g else "IN AIR")
		lbl_bal_foot_right.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4) if r_g else Color(0.5, 0.7, 1.0))

	# Update Balance Waveform Graph
	if graph_balance and graph_balance.has_method("add_sample"):
		graph_balance.call("add_sample", roll, pitch)

	# 5. Sensors Tab
	if lbl_sens_front: lbl_sens_front.text = "Front Ray: %.2fm" % sensors.get("front_distance", 0.0)
	if lbl_sens_left: lbl_sens_left.text = "Left Ray: %.2fm" % sensors.get("left_distance", 0.0)
	if lbl_sens_right: lbl_sens_right.text = "Right Ray: %.2fm" % sensors.get("right_distance", 0.0)
	if lbl_sens_min: lbl_sens_min.text = "Min Clearance: %.2fm" % sensors.get("min_distance", 0.0)

	var sens_status = avoidance.get("status_level", avoidance.get("action", "CLEAR"))
	if lbl_sens_status_banner:
		lbl_sens_status_banner.text = "Proximity Status: " + sens_status
		if sens_status == "CLEAR":
			lbl_sens_status_banner.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
		elif sens_status == "WARNING":
			lbl_sens_status_banner.add_theme_color_override("font_color", Color(0.95, 0.75, 0.1))
		else:
			lbl_sens_status_banner.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))

	# 6. Analytics Tab
	var dist_val = walking.get("walking_distance", 0.0)
	var spd_val = walking.get("instantaneous_speed", 0.0)
	if lbl_ana_distance: lbl_ana_distance.text = "Total Distance: %.2f m" % dist_val
	if lbl_ana_avg_speed: lbl_ana_avg_speed.text = "Instant Speed: %.2f m/s" % spd_val
	if lbl_ana_max_tilt: lbl_ana_max_tilt.text = "Max Tilt: %.1f°" % max_tilt_recorded
	if lbl_ana_falls: lbl_ana_falls.text = "Falls Sustained: %d" % int(fall_count)
	if lbl_ana_collisions: lbl_ana_collisions.text = "Collisions: %d" % collisions

	var stability_score = clamp(100.0 - (bal_error * 200.0) - (fall_count * 20.0), 0.0, 100.0)
	if lbl_ana_stability: lbl_ana_stability.text = "Stability Score: %.1f%%" % stability_score

	if graph_analytics and graph_analytics.has_method("add_sample"):
		graph_analytics.call("add_sample", spd_val, bal_error * 10.0)

	# 7. Experiments Tab
	if exp_data.size() > 0:
		var exp_active = exp_data.get("active", false)
		var exp_prog = exp_data.get("progress", 0.0)
		var exp_status_str = exp_data.get("status", "NOT_RUN")
		if prog_exp: prog_exp.value = exp_prog * 100.0
		if lbl_exp_status:
			lbl_exp_status.text = "Status: %s (Time: %.1fs)" % [exp_status_str, exp_data.get("elapsed_time", 0.0)]
			if exp_status_str in ["COMPLETED_SUCCESS", "PASSED"]:
				lbl_exp_status.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
			elif exp_status_str == "RUNNING":
				lbl_exp_status.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
			elif "FAILED" in exp_status_str:
				lbl_exp_status.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))

		var criteria = exp_data.get("criteria", [])
		if criteria is Array:
			if criteria.size() > 0 and chk_exp_c1: chk_exp_c1.button_pressed = criteria[0].get("met", false)
			if criteria.size() > 1 and chk_exp_c2: chk_exp_c2.button_pressed = criteria[1].get("met", false)
			if criteria.size() > 2 and chk_exp_c3: chk_exp_c3.button_pressed = criteria[2].get("met", false)
			if criteria.size() > 3 and chk_exp_c4: chk_exp_c4.button_pressed = criteria[3].get("met", false)
			if criteria.size() > 4 and chk_exp_c5: chk_exp_c5.button_pressed = criteria[4].get("met", false)
		elif criteria is Dictionary:
			if chk_exp_c1 and criteria.has("distance_met"): chk_exp_c1.button_pressed = criteria["distance_met"]
			if chk_exp_c2 and criteria.has("tilt_stable"): chk_exp_c2.button_pressed = criteria["tilt_stable"]
			if chk_exp_c3 and criteria.has("zero_falls"): chk_exp_c3.button_pressed = criteria["zero_falls"]

	# 8. Update Joint Sliders from telemetry
	var joints = data.get("joints", {})
	updating_from_telemetry = true
	for j_name in joints:
		if j_name in joint_ui_map:
			var j_data = joints[j_name]
			var curr_deg = j_data.get("current_deg", 0.0)
			var target_deg = j_data.get("target_deg", 0.0)
			joint_ui_map[j_name]["val_lbl"].text = "Cur: %+.1f° (Set: %+.1f°)" % [curr_deg, target_deg]
	updating_from_telemetry = false

	# 9. Update Bottom Event Log
	if event_log_list and events.size() > last_event_count:
		for i in range(last_event_count, events.size()):
			var ev = events[i]
			var t_str = ev.get("time_str", "")
			var cat = ev.get("category", "SYSTEM")
			var msg = ev.get("message", "")
			var sev = ev.get("severity", "INFO")
			var entry_text = "[%s] [%s] %s" % [t_str, cat, msg]
			var item_idx = event_log_list.add_item(entry_text)
			if sev == "CRITICAL":
				event_log_list.set_item_custom_fg_color(item_idx, Color(1.0, 0.3, 0.3))
			elif sev == "WARNING":
				event_log_list.set_item_custom_fg_color(item_idx, Color(1.0, 0.8, 0.2))
			else:
				event_log_list.set_item_custom_fg_color(item_idx, Color(0.7, 0.85, 1.0))
		last_event_count = events.size()
		event_log_list.ensure_current_is_visible()

func _unhandled_input(event: InputEvent) -> void:
	if not network_client or not is_instance_valid(network_client):
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_W, KEY_UP:
				network_client.set_direction("forward")
			KEY_S, KEY_DOWN:
				network_client.set_direction("backward")
			KEY_A, KEY_LEFT:
				network_client.set_direction("turn_left")
			KEY_D, KEY_RIGHT:
				network_client.set_direction("turn_right")
			KEY_SPACE:
				network_client.send_command("stop")
