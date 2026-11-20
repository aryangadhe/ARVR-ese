extends Node3D

@onready var network_client = $NetworkClient
@onready var robot_visualizer = $RobotVisualizer
@onready var obstacle_manager = $ObstacleManager
@onready var camera_controller = $CameraController

func _ready() -> void:
	if network_client:
		network_client.telemetry_received.connect(_on_telemetry_received)

func _on_telemetry_received(data: Dictionary) -> void:
	if robot_visualizer:
		robot_visualizer.update_from_telemetry(data)

	if obstacle_manager:
		obstacle_manager.update_obstacles(data.get("obstacles", []))

	if camera_controller and robot_visualizer:
		var pos_arr = data.get("position", [0, 0, 0.85])
		var g_pos = robot_visualizer.pb_to_godot_pos(pos_arr)
		camera_controller.set_target_position(g_pos)
