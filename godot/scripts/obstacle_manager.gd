extends Node3D
class_name ObstacleManager

var spawned_visuals: Dictionary = {}

func update_obstacles(obstacles_list: Array) -> void:
	var active_ids: Array = []

	for obs in obstacles_list:
		var id = obs.get("id", -1)
		active_ids.append(id)

		var obs_type = obs.get("type", "cube")
		var pos = obs.get("position", [0, 0, 0])
		# Convert PyBullet pos to Godot pos
		var g_pos = Vector3(-pos[1], pos[2], -pos[0])

		if not id in spawned_visuals:
			var node = _create_obstacle_node(obs_type, obs.get("size", []))
			node.name = "Obstacle_" + str(id)
			add_child(node)
			spawned_visuals[id] = node

		var quat = obs.get("orientation", [0, 0, 0, 1])
		var b = _pb_to_godot_basis(quat) if quat.size() >= 4 else Basis()
		spawned_visuals[id].global_transform = Transform3D(b, g_pos)

	# Clean up deleted obstacles
	var to_remove = []
	for id in spawned_visuals:
		if not id in active_ids:
			to_remove.append(id)

	for id in to_remove:
		var node = spawned_visuals[id]
		node.queue_free()
		spawned_visuals.erase(id)

func _pb_to_godot_basis(pb_quat: Array) -> Basis:
	var q = Quaternion(pb_quat[0], pb_quat[1], pb_quat[2], pb_quat[3])
	var wx = q * Vector3(1.0, 0.0, 0.0)
	var wy = q * Vector3(0.0, 1.0, 0.0)
	var wz = q * Vector3(0.0, 0.0, 1.0)
	var gx = Vector3(wy.y, -wy.z, wy.x)
	var gy = Vector3(-wz.y, wz.z, -wz.x)
	var gz = Vector3(wx.y, -wx.z, wx.x)
	return Basis(gx, gy, gz)

func _create_obstacle_node(obs_type: String, size_array: Array) -> Node3D:
	var mesh_inst = MeshInstance3D.new()
	var mat = StandardMaterial3D.new()
	mat.roughness = 0.4
	mat.metallic = 0.2

	if obs_type == "cylinder":
		var cyl = CylinderMesh.new()
		cyl.top_radius = size_array[0] if size_array.size() > 0 else 0.25
		cyl.bottom_radius = cyl.top_radius
		cyl.height = size_array[1] if size_array.size() > 1 else 0.8
		mesh_inst.mesh = cyl
		mat.albedo_color = Color(0.9, 0.4, 0.2)
	elif obs_type == "wall":
		var box = BoxMesh.new()
		var hx = size_array[0] if size_array.size() > 0 else 0.1
		var hy = size_array[1] if size_array.size() > 1 else 1.2
		var hz = size_array[2] if size_array.size() > 2 else 0.5
		box.size = Vector3(hy * 2.0, hz * 2.0, hx * 2.0)
		mesh_inst.mesh = box
		mat.albedo_color = Color(0.3, 0.55, 0.8)
	elif obs_type == "barrier":
		var box = BoxMesh.new()
		var hx = size_array[0] if size_array.size() > 0 else 0.15
		var hy = size_array[1] if size_array.size() > 1 else 0.8
		var hz = size_array[2] if size_array.size() > 2 else 0.35
		box.size = Vector3(hy * 2.0, hz * 2.0, hx * 2.0)
		mesh_inst.mesh = box
		mat.albedo_color = Color(0.95, 0.50, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.1, 0.0)
	elif obs_type == "ramp":
		var box = BoxMesh.new()
		var hx = size_array[0] if size_array.size() > 0 else 0.8
		var hy = size_array[1] if size_array.size() > 1 else 0.5
		var hz = size_array[2] if size_array.size() > 2 else 0.12
		box.size = Vector3(hy * 2.0, hz * 2.0, hx * 2.0)
		mesh_inst.mesh = box
		mat.albedo_color = Color(0.25, 0.65, 0.85)
		mat.roughness = 0.6
	else: # default cube
		var box = BoxMesh.new()
		var hx = size_array[0] if size_array.size() > 0 else 0.25
		var hy = size_array[1] if size_array.size() > 1 else 0.25
		var hz = size_array[2] if size_array.size() > 2 else 0.4
		box.size = Vector3(hy * 2.0, hz * 2.0, hx * 2.0)
		mesh_inst.mesh = box
		mat.albedo_color = Color(0.95, 0.6, 0.15)

	mesh_inst.material_override = mat
	return mesh_inst

