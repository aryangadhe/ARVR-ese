extends Node3D

@onready var network_client = $NetworkClient
@onready var robot_visualizer = $RobotVisualizer
@onready var obstacle_manager = $ObstacleManager
@onready var camera_controller = $CameraController

# 3D Goal Beacon and Path Visualizer
var goal_node: Node3D
var goal_beacon_mesh: MeshInstance3D
var goal_ring_mesh: MeshInstance3D
var path_mesh_inst: MeshInstance3D
var path_immediate_mesh: ImmediateMesh

var _mouse_press_pos: Vector2 = Vector2.ZERO
var _mouse_press_time: int = 0
var _pulse_timer: float = 0.0
var _printed_first_telemetry: bool = false

func _ready() -> void:
	print("[Main] _ready invoked. network_client=", network_client, " rob_vis=", robot_visualizer)
	if network_client:
		network_client.telemetry_received.connect(_on_telemetry_received)
		print("[Main] Connected to network_client.telemetry_received")
	else:
		printerr("[Main] ERROR: network_client is null!")

	_setup_navigation_visualizers()

func _setup_navigation_visualizers() -> void:
	# 1. 3D Goal Beacon Container
	goal_node = Node3D.new()
	goal_node.name = "GoalBeacon"
	goal_node.visible = false
	add_child(goal_node)

	# Goal Vertical Beam / Pillar
	goal_beacon_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.14
	cyl.height = 1.6
	goal_beacon_mesh.mesh = cyl
	goal_beacon_mesh.position = Vector3(0, 0.8, 0)
	var b_mat = StandardMaterial3D.new()
	b_mat.albedo_color = Color(0.0, 0.85, 1.0, 0.75)
	b_mat.emission_enabled = true
	b_mat.emission = Color(0.0, 0.8, 1.0)
	b_mat.emission_energy_multiplier = 3.2
	b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	goal_beacon_mesh.material_override = b_mat
	goal_node.add_child(goal_beacon_mesh)

	# Goal Pulsing Ground Target Ring
	goal_ring_mesh = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.40
	torus.outer_radius = 0.48
	goal_ring_mesh.mesh = torus
	goal_ring_mesh.position = Vector3(0, 0.03, 0)
	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_color = Color(0.0, 1.0, 0.8, 0.9)
	r_mat.emission_enabled = true
	r_mat.emission = Color(0.0, 1.0, 0.8)
	r_mat.emission_energy_multiplier = 2.8
	goal_ring_mesh.material_override = r_mat
	goal_node.add_child(goal_ring_mesh)

	# 2. Optimal Navigation Path Ribbon (ImmediateMesh line strip on floor)
	path_mesh_inst = MeshInstance3D.new()
	path_mesh_inst.name = "OptimalPathRibbon"
	path_immediate_mesh = ImmediateMesh.new()
	path_mesh_inst.mesh = path_immediate_mesh
	add_child(path_mesh_inst)

func _process(delta: float) -> void:
	if goal_node and goal_node.visible:
		_pulse_timer += delta * 4.5
		var s = 1.0 + 0.12 * sin(_pulse_timer)
		goal_ring_mesh.scale = Vector3(s, 1.0, s)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_mouse_press_pos = mb.position
				_mouse_press_time = Time.get_ticks_msec()
				# If holding Shift, immediately set goal on press
				if mb.shift_pressed:
					_handle_floor_click(mb.position)
			else:
				var drag_dist = mb.position.distance_to(_mouse_press_pos)
				# Clean click on ground (within 22px tolerance, not camera orbit drag)
				if drag_dist < 22.0:
					_handle_floor_click(mb.position)

func _handle_floor_click(screen_pos: Vector2) -> void:
	var cam: Camera3D = null
	if camera_controller and camera_controller.camera:
		cam = camera_controller.camera
	elif get_viewport().get_camera_3d():
		cam = get_viewport().get_camera_3d()

	if not cam:
		return

	var ray_origin = cam.project_ray_origin(screen_pos)
	var ray_normal = cam.project_ray_normal(screen_pos)

	# Ray-plane intersection with horizontal ground plane Y = 0
	if abs(ray_normal.y) > 0.0001:
		var t = -ray_origin.y / ray_normal.y
		if t > 0.0:
			var hit_pos = ray_origin + ray_normal * t

			# Convert Godot 3D coordinates to PyBullet 2D coordinates:
			# Godot: x = -Y_pb, y = Z_pb, z = -X_pb
			# PyBullet: X_pb = -hit_pos.z, Y_pb = -hit_pos.x
			var pb_x = -hit_pos.z
			var pb_y = -hit_pos.x

			# Clamp within arena bounds
			pb_x = clamp(pb_x, -12.0, 12.0)
			pb_y = clamp(pb_y, -12.0, 12.0)

			print("[Main] Click-to-Goal set: PyBullet (", snapped(pb_x, 0.01), ", ", snapped(pb_y, 0.01), ")")
			if network_client:
				network_client.navigate_to_goal(pb_x, pb_y)

			# Show beacon immediately at clicked position
			_set_beacon_position(Vector3(hit_pos.x, 0.0, hit_pos.z))
			goal_node.visible = true

func _set_beacon_position(g_pos: Vector3) -> void:
	if goal_node:
		goal_node.global_position = Vector3(g_pos.x, 0.0, g_pos.z)

func _on_telemetry_received(data: Dictionary) -> void:
	if not _printed_first_telemetry:
		_printed_first_telemetry = true
		print("[Main] First telemetry received! Keys: ", data.keys())

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

	# Update Navigation Goal Beacon and Optimal Path Ribbon
	var nav_data = data.get("navigation", {})
	_update_navigation_visualizer(nav_data, data.get("position", [0, 0, 0.85]))

func _update_navigation_visualizer(nav_data: Dictionary, robot_pb_pos: Array) -> void:
	if not nav_data or not nav_data.get("active", false):
		if nav_data.get("status", "") == "REACHED":
			# Target reached: change beacon color to emerald green!
			if goal_beacon_mesh and goal_beacon_mesh.material_override:
				(goal_beacon_mesh.material_override as StandardMaterial3D).emission = Color(0.1, 1.0, 0.3)
			if goal_ring_mesh and goal_ring_mesh.material_override:
				(goal_ring_mesh.material_override as StandardMaterial3D).emission = Color(0.1, 1.0, 0.3)
		else:
			if goal_node:
				goal_node.visible = false
			if path_immediate_mesh:
				path_immediate_mesh.clear_surfaces()
		return

	# Navigation is active
	goal_node.visible = true
	var goal_pb = nav_data.get("goal", [])
	if goal_pb.size() >= 2:
		var g_x = -float(goal_pb[1])
		var g_z = -float(goal_pb[0])
		_set_beacon_position(Vector3(g_x, 0.0, g_z))

	# Reset beacon emission to electric cyan while navigating
	if goal_beacon_mesh and goal_beacon_mesh.material_override:
		(goal_beacon_mesh.material_override as StandardMaterial3D).emission = Color(0.0, 0.8, 1.0)
	if goal_ring_mesh and goal_ring_mesh.material_override:
		(goal_ring_mesh.material_override as StandardMaterial3D).emission = Color(0.0, 1.0, 0.8)

	# Draw optimal navigation path ribbon
	var path_pts = nav_data.get("path", [])
	if path_pts.size() > 0 and path_immediate_mesh:
		path_immediate_mesh.clear_surfaces()
		var p_mat = StandardMaterial3D.new()
		p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p_mat.albedo_color = Color(0.0, 0.9, 1.0, 0.95)

		path_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, p_mat)

		# Start line at current robot ground position
		var r_gx = -float(robot_pb_pos[1])
		var r_gz = -float(robot_pb_pos[0])
		path_immediate_mesh.surface_add_vertex(Vector3(r_gx, 0.035, r_gz))

		# Add all waypoints in the optimal path
		for pt in path_pts:
			var wp_gx = -float(pt[1])
			var wp_gz = -float(pt[0])
			path_immediate_mesh.surface_add_vertex(Vector3(wp_gx, 0.035, wp_gz))

		path_immediate_mesh.surface_end()
