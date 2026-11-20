extends Node3D
class_name RobotVisualizer

# Dictionary mapping URDF link names to Node3D visual instances
var link_nodes: Dictionary = {}

# Sensor ray visualization
@onready var rays_container: Node3D = $SensorRays
var ray_meshes: Dictionary = {}

func _ready() -> void:
	_register_links()
	_setup_ray_visualizers()

func _register_links() -> void:
	var links_group = $Links
	if links_group:
		for child in links_group.get_children():
			if child is Node3D:
				link_nodes[child.name] = child

func _setup_ray_visualizers() -> void:
	if not rays_container:
		return
	for ray_name in ["front", "left", "right"]:
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.name = "Ray_" + ray_name
		var imm = ImmediateMesh.new()
		mesh_inst.mesh = imm
		rays_container.add_child(mesh_inst)
		ray_meshes[ray_name] = mesh_inst

func pb_to_godot_pos(pb_pos: Array) -> Vector3:
	# pb: [x=fwd, y=left, z=up] -> godot: [x=right=-y, y=up=z, z=fwd=-x]
	return Vector3(-pb_pos[1], pb_pos[2], -pb_pos[0])

func pb_to_godot_basis(pb_quat: Array) -> Basis:
	var q = Quaternion(pb_quat[0], pb_quat[1], pb_quat[2], pb_quat[3])
	var wx = q * Vector3(1.0, 0.0, 0.0)
	var wy = q * Vector3(0.0, 1.0, 0.0)
	var wz = q * Vector3(0.0, 0.0, 1.0)

	var gx = Vector3(wy.y, -wy.z, wy.x)
	var gy = Vector3(-wz.y, wz.z, -wz.x)
	var gz = Vector3(wx.y, -wx.z, wx.x)

	return Basis(gx, gy, gz)

func update_from_telemetry(data: Dictionary) -> void:
	var links_data = data.get("links", {})
	for link_name in links_data:
		if link_name in link_nodes:
			var node: Node3D = link_nodes[link_name]
			var info = links_data[link_name]
			var pos_array = info.get("position", [0, 0, 0])
			var quat_array = info.get("orientation", [0, 0, 0, 1])

			node.global_position = pb_to_godot_pos(pos_array)
			node.global_transform.basis = pb_to_godot_basis(quat_array)

	_update_sensor_rays(data.get("sensors", {}))

func _update_sensor_rays(sensor_data: Dictionary) -> void:
	var rays = sensor_data.get("rays", [])
	for ray_info in rays:
		var name = ray_info.get("name", "")
		if name in ray_meshes:
			var mesh_inst: MeshInstance3D = ray_meshes[name]
			var imm: ImmediateMesh = mesh_inst.mesh
			imm.clear_surfaces()

			var from_pos = pb_to_godot_pos(ray_info.get("from", [0, 0, 0.9]))
			var has_hit = ray_info.get("has_hit", false)
			var to_pos = pb_to_godot_pos(
				ray_info.get("hit_position" if has_hit else "to", [1, 0, 0.9])
			)

			var mat = StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(1.0, 0.25, 0.15) if has_hit else Color(0.1, 0.9, 0.6)

			imm.surface_begin(Mesh.PRIMITIVE_LINES, mat)
			imm.surface_add_vertex(from_pos)
			imm.surface_add_vertex(to_pos)
			imm.surface_end()

