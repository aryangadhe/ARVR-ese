extends Control
class_name UIController

@export var network_client: Node
@export var camera_controller: Node3D

# UI Node References
var status_connection: Label
var status_xr: Label
var lbl_state: Label
var lbl_balance: Label
var lbl_fall_count: Label
var lbl_rpy: Label
var lbl_pos: Label
var lbl_walking_phase: Label
var lbl_sensor_dist: Label
var lbl_avoidance: Label

# Joint Sliders container
var joint_container: VBoxContainer

# Sliders dictionary: {joint_name: {"slider": HSlider, "val_lbl": Label}}
var joint_ui_map: Dictionary = {}
var updating_from_telemetry: bool = false

# Joint display labels & limits (in degrees)
const JOINT_DEFS = {
	"neck_pitch": {"min": -34.0, "max": 34.0, "default": 0.0, "title": "Neck Pitch"},
	"left_shoulder_pitch": {"min": -100.0, "max": 100.0, "default": 0.0, "title": "L Shoulder Pitch"},
	"left_elbow_pitch": {"min": 0.0, "max": 125.0, "default": 20.0, "title": "L Elbow Pitch"},
	"right_shoulder_pitch": {"min": -100.0, "max": 100.0, "default": 0.0, "title": "R Shoulder Pitch"},
	"right_elbow_pitch": {"min": 0.0, "max": 125.0, "default": 20.0, "title": "R Elbow Pitch"},
	"left_hip_roll": {"min": -20.0, "max": 20.0, "default": 0.0, "title": "L Hip Roll"},
	"left_hip_pitch": {"min": -68.0, "max": 68.0, "default": -6.8, "title": "L Hip Pitch"},
	"left_knee_pitch": {"min": 0.0, "max": 125.0, "default": 13.7, "title": "L Knee Pitch"},
	"left_ankle_pitch": {"min": -40.0, "max": 40.0, "default": -6.8, "title": "L Ankle Pitch"},
	"right_hip_roll": {"min": -20.0, "max": 20.0, "default": 0.0, "title": "R Hip Roll"},
	"right_hip_pitch": {"min": -68.0, "max": 68.0, "default": -6.8, "title": "R Hip Pitch"},
	"right_knee_pitch": {"min": 0.0, "max": 125.0, "default": 13.7, "title": "R Knee Pitch"},
	"right_ankle_pitch": {"min": -40.0, "max": 40.0, "default": -6.8, "title": "R Ankle Pitch"},
}

func _ready() -> void:
	_resolve_nodes()
	_build_joint_sliders()
	_connect_control_buttons()

func _resolve_nodes() -> void:
	status_connection = find_child("LblConnection", true, false) as Label
	status_xr = find_child("LblXR", true, false) as Label
	lbl_state = find_child("LblState", true, false) as Label
	lbl_balance = find_child("LblBalance", true, false) as Label
	lbl_fall_count = find_child("LblFallCount", true, false) as Label
	lbl_rpy = find_child("LblRPY", true, false) as Label
	lbl_pos = find_child("LblPos", true, false) as Label
	lbl_walking_phase = find_child("LblWalkPhase", true, false) as Label
	lbl_sensor_dist = find_child("LblSensors", true, false) as Label
	lbl_avoidance = find_child("LblAvoidance", true, false) as Label
	joint_container = find_child("JointsVBox", true, false) as VBoxContainer

func _connect_control_buttons() -> void:
	if not network_client:
		network_client = get_node_or_null("../NetworkClient")

	if network_client:
		network_client.connected_to_server.connect(_on_network_connected)
		network_client.disconnected_from_server.connect(_on_network_disconnected)
		network_client.telemetry_received.connect(_on_telemetry_received)

	_bind_button("BtnWalk", func(): network_client.send_command("walk"))
	_bind_button("BtnStop", func(): network_client.send_command("stop"))
	_bind_button("BtnStand", func(): network_client.send_command("stand"))
	_bind_button("BtnReset", func(): network_client.send_command("reset"))

	_bind_button("BtnSmallPush", func(): network_client.send_push(60.0, "forward", 0.15))
	_bind_button("BtnMedPush", func(): network_client.send_push(160.0, "forward", 0.15))
	_bind_button("BtnStrongPush", func(): network_client.send_push(350.0, "forward", 0.20))

	_bind_button("BtnSpawnCube", func(): network_client.spawn_obstacle("cube", [1.8, 0.0, 0.4], [0.25, 0.25, 0.4]))
	_bind_button("BtnSpawnCyl", func(): network_client.spawn_obstacle("cylinder", [2.2, 0.5, 0.4], [0.25, 0.8]))
	_bind_button("BtnSpawnWall", func(): network_client.spawn_obstacle("wall", [-2.0, 0.0, 0.5], [0.1, 1.5, 0.5]))
	_bind_button("BtnClearObs", func(): network_client.clear_obstacles())

	var chk_avoid: CheckBox = find_child("ChkAvoidance", true, false) as CheckBox
	if chk_avoid and network_client:
		chk_avoid.toggled.connect(func(toggled): network_client.toggle_avoidance(toggled))

	var sld_speed: HSlider = find_child("SldWalkSpeed", true, false) as HSlider
	if sld_speed and network_client:
		sld_speed.value_changed.connect(func(val): network_client.set_speed(val))

	_bind_button("BtnResetCam", func():
		if camera_controller:
			camera_controller.reset_camera()
	)

	_bind_button("BtnResetAllJoints", func():
		if network_client:
			network_client.clear_all_joints()
	)

func _bind_button(node_name: String, callback: Callable) -> void:
	var btn: Button = find_child(node_name, true, false) as Button
	if btn:
		btn.pressed.connect(callback)

func _build_joint_sliders() -> void:
	if not joint_container:
		return

	for j_name in JOINT_DEFS:
		var def = JOINT_DEFS[j_name]
		var row = VBoxContainer.new()
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
		row.add_child(header_hbox)

		var slider = HSlider.new()
		slider.min_value = def["min"]
		slider.max_value = def["max"]
		slider.step = 1.0
		slider.value = def["default"]
		slider.custom_minimum_size = Vector2(200, 20)

		var current_joint = j_name
		slider.value_changed.connect(func(new_val):
			val_lbl.text = str(round(new_val)) + "°"
			if not updating_from_telemetry and network_client:
				network_client.send_joint_command(current_joint, new_val)
		)

		row.add_child(slider)
		joint_container.add_child(row)

		joint_ui_map[j_name] = {
			"slider": slider,
			"val_lbl": val_lbl,
		}

func _on_network_connected() -> void:
	if status_connection:
		status_connection.text = "● SIMULATION BACKEND CONNECTED"
		status_connection.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))

func _on_network_disconnected() -> void:
	if status_connection:
		status_connection.text = "○ DISCONNECTED (RETRYING...)"
		status_connection.add_theme_color_override("font_color", Color(0.9, 0.3, 0.2))

func _on_telemetry_received(data: Dictionary) -> void:
	if lbl_state:
		var state_str = data.get("state", "UNKNOWN")
		lbl_state.text = "State: " + state_str
		if state_str == "STANDING" or state_str == "WALKING":
			lbl_state.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
		elif state_str == "UNSTABLE" or state_str == "BALANCING":
			lbl_state.add_theme_color_override("font_color", Color(0.95, 0.7, 0.1))
		else:
			lbl_state.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))

	if lbl_balance:
		lbl_balance.text = "Balance: " + data.get("balance", "UNKNOWN")
	if lbl_fall_count:
		lbl_fall_count.text = "Fall Count: " + str(data.get("fall_count", 0))

	if lbl_rpy:
		lbl_rpy.text = "R: %+.1f° | P: %+.1f° | Y: %+.1f°" % [
			data.get("roll", 0.0),
			data.get("pitch", 0.0),
			data.get("yaw", 0.0)
		]

	if lbl_pos:
		var pos = data.get("position", [0, 0, 0])
		lbl_pos.text = "Pos: (%.2f, %.2f, %.2f)m" % [pos[0], pos[1], pos[2]]

	var walking = data.get("walking", {})
	if lbl_walking_phase:
		lbl_walking_phase.text = "Gait: " + ("WALKING (" + walking.get("phase", "") + ")" if walking.get("active", false) else "STAND / IDLE")

	var sensors = data.get("sensors", {})
	if lbl_sensor_dist:
		lbl_sensor_dist.text = "Sensors: F: %.2fm | L: %.2fm | R: %.2fm" % [
			sensors.get("front_distance", 0.0),
			sensors.get("left_distance", 0.0),
			sensors.get("right_distance", 0.0)
		]

	var avoidance = data.get("obstacle_avoidance", {})
	if lbl_avoidance:
		lbl_avoidance.text = "Avoidance: " + avoidance.get("action", "CLEAR")

	var joints = data.get("joints", {})
	updating_from_telemetry = true
	for j_name in joints:
		if j_name in joint_ui_map:
			var j_data = joints[j_name]
			var curr_deg = j_data.get("current_deg", 0.0)
			var target_deg = j_data.get("target_deg", 0.0)
			joint_ui_map[j_name]["val_lbl"].text = "Cur: %+.1f° (Set: %+.1f°)" % [curr_deg, target_deg]
	updating_from_telemetry = false
