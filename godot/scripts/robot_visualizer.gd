extends Node3D
class_name RobotVisualizer

# Dictionary mapping URDF link names to Node3D visual instances
var link_nodes: Dictionary = {}
var original_materials: Dictionary = {}

# Sensor ray visualization
@onready var rays_container: Node3D = $SensorRays
var ray_meshes: Dictionary = {}

# Center of Mass and Support Polygon Visualizers
var com_sphere: MeshInstance3D
var com_ground_proj: MeshInstance3D
var support_poly_inst: MeshInstance3D
var support_poly_mesh: ImmediateMesh
var highlighted_node: Node3D = null

func _ready() -> void:
	_register_links()
	_setup_ray_visualizers()
	_setup_com_visualizers()

func _setup_com_visualizers() -> void:
	# 1. 3D Center of Mass sphere
	com_sphere = MeshInstance3D.new()
	com_sphere.name = "COM_Sphere"
	var sm = SphereMesh.new()
	sm.radius = 0.045
	sm.height = 0.09
	com_sphere.mesh = sm
	var com_mat = StandardMaterial3D.new()
	com_mat.albedo_color = Color(0.0, 0.9, 1.0, 0.85)
	com_mat.emission_enabled = true
	com_mat.emission = Color(0.0, 0.7, 1.0)
	com_mat.emission_energy_multiplier = 1.5
	com_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	com_sphere.material_override = com_mat
	add_child(com_sphere)

	# 2. COM Ground projection disk
	com_ground_proj = MeshInstance3D.new()
	com_ground_proj.name = "COM_GroundProjection"
	var cyl_proj = CylinderMesh.new()
	cyl_proj.top_radius = 0.05
	cyl_proj.bottom_radius = 0.05
	cyl_proj.height = 0.008
	com_ground_proj.mesh = cyl_proj
	var proj_mat = StandardMaterial3D.new()
	proj_mat.albedo_color = Color(0.2, 1.0, 0.5, 0.9)
	proj_mat.emission_enabled = true
	proj_mat.emission = Color(0.1, 0.9, 0.4)
	com_ground_proj.material_override = proj_mat
	add_child(com_ground_proj)

	# 3. Support Polygon ground outline
	support_poly_inst = MeshInstance3D.new()
	support_poly_inst.name = "SupportPolygonOutline"
	support_poly_mesh = ImmediateMesh.new()
	support_poly_inst.mesh = support_poly_mesh
	add_child(support_poly_inst)

func highlight_link(link_name: String) -> void:
	# Clear previous highlight
	if highlighted_node and is_instance_valid(highlighted_node):
		var orig_mat = original_materials.get(highlighted_node.name, null)
		if highlighted_node is MeshInstance3D:
			(highlighted_node as MeshInstance3D).material_override = orig_mat
		highlighted_node = null

	if link_name.is_empty():
		return

	if link_name in link_nodes:
		var target: Node3D = link_nodes[link_name]
		highlighted_node = target
		var highlight_mat = StandardMaterial3D.new()
		highlight_mat.albedo_color = Color(1.0, 0.85, 0.1)
		highlight_mat.emission_enabled = true
		highlight_mat.emission = Color(1.0, 0.8, 0.0)
		highlight_mat.emission_energy_multiplier = 2.0
		if target is MeshInstance3D:
			(target as MeshInstance3D).material_override = highlight_mat

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
	_update_balance_geometry(data)

func _update_balance_geometry(data: Dictionary) -> void:
	# 1. Update COM 3D sphere
	if com_sphere and data.has("center_of_mass"):
		var com_pb = data.get("center_of_mass", [0, 0, 0])
		com_sphere.global_position = pb_to_godot_pos(com_pb)

	# 2. Update COM Ground Projection disk
	if com_ground_proj:
		var com_proj_pb = data.get("com_ground_projection", [0, 0, 0])
		var g_pos = pb_to_godot_pos(com_proj_pb)
		com_ground_proj.global_position = Vector3(g_pos.x, 0.005, g_pos.z)

	# 3. Update Support Polygon outline
	if support_poly_mesh and data.has("support_polygon"):
		support_poly_mesh.clear_surfaces()
		var poly = data.get("support_polygon", [])
		if poly.size() >= 3:
			var mat = StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(0.2, 0.9, 0.4, 0.8)

			support_poly_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
			for pt in poly:
				var g_pt = Vector3(-pt[1], 0.008, -pt[0])
				support_poly_mesh.surface_add_vertex(g_pt)
			# Close loop
			var first_pt = poly[0]
			support_poly_mesh.surface_add_vertex(Vector3(-first_pt[1], 0.008, -first_pt[0]))
			support_poly_mesh.surface_end()

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

