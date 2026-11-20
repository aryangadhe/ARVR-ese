extends Node3D
class_name CameraController

@export var target_node: Node3D
@export var orbit_speed: float = 0.005
@export var pan_speed: float = 0.005
@export var zoom_speed: float = 0.5
@export var min_distance: float = 0.8
@export var max_distance: float = 12.0

var distance: float = 2.8
var pitch: float = -0.30
var yaw: float = 0.785  # ~45 deg
var target_offset: Vector3 = Vector3(0, 0.85, 0)

var is_orbiting: bool = false
var is_panning: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

var current_mode: String = "ORBIT"
var robot_pos_cached: Vector3 = Vector3(0, 0.85, 0)

# Target values for smooth preset transitions
var target_distance: float = 2.8
var target_pitch: float = -0.30
var target_yaw: float = 0.785
var transitioning: bool = false

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	reset_camera()
	_update_transform()

func _process(delta: float) -> void:
	if current_mode == "FOLLOW":
		target_offset = target_offset.lerp(robot_pos_cached + Vector3(0, 0.4, 0), delta * 4.0)
		_update_transform()

	if transitioning:
		distance = lerp(distance, target_distance, delta * 6.0)
		pitch = lerp(pitch, target_pitch, delta * 6.0)
		yaw = lerp(yaw, target_yaw, delta * 6.0)
		if abs(distance - target_distance) < 0.02 and abs(pitch - target_pitch) < 0.02:
			transitioning = false
		_update_transform()

func set_mode(mode: String) -> void:
	current_mode = mode
	match mode:
		"ORBIT":
			target_distance = 3.2
			target_pitch = -0.35
			target_yaw = 0.785
			target_offset = robot_pos_cached + Vector3(0, 0.4, 0)
			transitioning = true
		"FOLLOW":
			target_distance = 2.8
			target_pitch = -0.25
			target_yaw = 0.4
			transitioning = true
		"FRONT":
			target_distance = 3.0
			target_pitch = -0.10
			target_yaw = 3.14159  # Facing front
			target_offset = robot_pos_cached + Vector3(0, 0.5, 0)
			transitioning = true
		"SIDE":
			target_distance = 3.0
			target_pitch = -0.10
			target_yaw = 1.5708  # Profile view
			target_offset = robot_pos_cached + Vector3(0, 0.5, 0)
			transitioning = true
		"TOP":
			target_distance = 4.5
			target_pitch = -1.45  # Near 90 deg down
			target_yaw = 0.0
			target_offset = robot_pos_cached + Vector3(0, 0.0, 0)
			transitioning = true
		"FREE":
			transitioning = false

func reset_camera() -> void:
	set_mode("ORBIT")

func update_robot_pos(pos: Vector3) -> void:
	robot_pos_cached = pos
	if current_mode == "FOLLOW":
		target_offset = robot_pos_cached + Vector3(0, 0.4, 0)
		_update_transform()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			is_orbiting = mb.pressed
			last_mouse_pos = mb.position
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = mb.pressed
			last_mouse_pos = mb.position
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clamp(distance - zoom_speed, min_distance, max_distance)
			_update_transform()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clamp(distance + zoom_speed, min_distance, max_distance)
			_update_transform()

	elif event is InputEventMouseMotion:
		var mm = event as InputEventMouseMotion
		var delta = mm.position - last_mouse_pos
		last_mouse_pos = mm.position

		if is_orbiting:
			yaw -= delta.x * orbit_speed
			pitch = clamp(pitch - delta.y * orbit_speed, -1.45, 1.45)
			_update_transform()
		elif is_panning:
			var right = global_transform.basis.x
			var up = global_transform.basis.y
			target_offset -= (right * delta.x - up * delta.y) * pan_speed
			_update_transform()

func set_target_position(pos: Vector3) -> void:
	robot_pos_cached = pos
	if current_mode == "FOLLOW":
		target_offset = Vector3(pos.x, pos.y + 0.3, pos.z)
		_update_transform()
	elif current_mode == "ORBIT":
		target_offset.x = lerp(target_offset.x, pos.x, 0.1)
		target_offset.z = lerp(target_offset.z, pos.z, 0.1)
		target_offset.y = lerp(target_offset.y, pos.y + 0.1, 0.1)
		_update_transform()

func _update_transform() -> void:
	# Spherical orbit calculation
	var cx = distance * cos(pitch) * sin(yaw)
	var cy = -distance * sin(pitch)
	var cz = distance * cos(pitch) * cos(yaw)
	var cam_pos = target_offset + Vector3(cx, cy, cz)

	global_position = cam_pos
	look_at(target_offset, Vector3.UP)

