extends Node3D
class_name CameraController

@export var target_node: Node3D
@export var orbit_speed: float = 0.005
@export var pan_speed: float = 0.005
@export var zoom_speed: float = 0.5
@export var min_distance: float = 0.8
@export var max_distance: float = 12.0

var distance: float = 3.0
var pitch: float = -0.3
var yaw: float = 0.785  # ~45 deg
var target_offset: Vector3 = Vector3(0, 0.8, 0)

var is_orbiting: bool = false
var is_panning: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	reset_camera()
	_update_transform()

func reset_camera() -> void:
	distance = 3.2
	pitch = -0.35
	yaw = 0.785
	target_offset = Vector3(0, 0.8, 0)
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
	target_offset = Vector3(pos.x, pos.y + 0.3, pos.z)
	_update_transform()

func _update_transform() -> void:
	# Spherical orbit calculation
	var cx = distance * cos(pitch) * sin(yaw)
	var cy = -distance * sin(pitch)
	var cz = distance * cos(pitch) * cos(yaw)
	var cam_pos = target_offset + Vector3(cx, cy, cz)

	global_position = cam_pos
	look_at(target_offset, Vector3.UP)

