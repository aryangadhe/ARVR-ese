extends Node3D

@onready var network_client = $NetworkClient
@onready var robot_visualizer = $RobotVisualizer
@onready var obstacle_manager = $ObstacleManager
@onready var camera_controller = $CameraController

func _ready() -> void:
	print("[Main] _ready invoked. network_client=", network_client, " rob_vis=", robot_visualizer)
	if network_client:
		network_client.telemetry_received.connect(_on_telemetry_received)
		print("[Main] Connected to network_client.telemetry_received")
	else:
		printerr("[Main] ERROR: network_client is null!")

var _printed_first_telemetry = false

func _on_telemetry_received(data: Dictionary) -> void:
	if not _printed_first_telemetry:
		_printed_first_telemetry = true
		print("[Main] First telemetry received! Keys: ", data.keys())
		print("[Main] Links in telemetry: ", data.get("links", {}).keys())

	if robot_visualizer:
		robot_visualizer.update_from_telemetry(data)
	else:
		printerr("[Main] ERROR: robot_visualizer is null in _on_telemetry_received!")

	if obstacle_manager:
		obstacle_manager.update_obstacles(data.get("obstacles", []))

	if camera_controller and robot_visualizer:
		var pos_arr = data.get("position", [0, 0, 0.85])
		var g_pos = robot_visualizer.pb_to_godot_pos(pos_arr)
		camera_controller.set_target_position(g_pos)


