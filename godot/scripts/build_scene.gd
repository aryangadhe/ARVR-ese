@tool
extends SceneTree

func _init() -> void:
	print("[Builder] Generating Professional Edition main.tscn for VR Humanoid Robot Simulator...")
	var root = Node3D.new()
	root.name = "Main"

	# Load scripts
	var main_script = load("res://scripts/main.gd")
	var net_script = load("res://scripts/network_client.gd")
	var cam_script = load("res://scripts/camera_controller.gd")
	var rob_script = load("res://scripts/robot_visualizer.gd")
	var obs_script = load("res://scripts/obstacle_manager.gd")
	var ui_script = load("res://scripts/ui_controller.gd")
	var xr_script = load("res://xr/xr_manager.gd")
	var graph_script = load("res://scripts/live_graph.gd")

	root.set_script(main_script)

	# Load materials
	var mat_torso = load("res://materials/torso.tres")
	var mat_limbs = load("res://materials/limbs.tres")
	var mat_joints = load("res://materials/joints.tres")
	var mat_visor = load("res://materials/visor.tres")
	var mat_floor = load("res://materials/floor.tres")

	# Load textures
	var tex_floor = load("res://textures/floor_grid.png")
	var tex_wall = load("res://textures/wall_panel.png")
	var tex_hazard = load("res://textures/hazard_stripes.png")

	if tex_floor:
		mat_floor.albedo_color = Color(0.95, 0.98, 1.0)
		mat_floor.albedo_texture = tex_floor
		mat_floor.uv1_scale = Vector3(40, 40, 40)
		mat_floor.roughness = 0.35
		mat_floor.metallic = 0.25
		mat_floor.emission_enabled = true
		mat_floor.emission = Color(0.0, 0.40, 0.65)
		mat_floor.emission_energy_multiplier = 0.35
		mat_floor.emission_texture = tex_floor

	# Save updated floor material
	ResourceSaver.save(mat_floor, "res://materials/floor.tres")

	# Modular metallic wall panel material
	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.88, 0.92, 0.96)
	if tex_wall:
		wall_mat.albedo_texture = tex_wall
		wall_mat.uv1_scale = Vector3(16, 3, 1)
	wall_mat.metallic = 0.45
	wall_mat.roughness = 0.35

	# Industrial safety hazard material
	var mat_hazard = StandardMaterial3D.new()
	mat_hazard.albedo_color = Color(1.0, 1.0, 1.0)
	if tex_hazard:
		mat_hazard.albedo_texture = tex_hazard
		mat_hazard.uv1_scale = Vector3(8, 1, 1)
	mat_hazard.metallic = 0.2
	mat_hazard.roughness = 0.4

	# High-grip track lane material
	var mat_track = StandardMaterial3D.new()
	mat_track.albedo_color = Color(0.10, 0.13, 0.18)
	mat_track.roughness = 0.55
	mat_track.metallic = 0.15

	# High-tech laboratory test platform material
	var mat_platform = StandardMaterial3D.new()
	mat_platform.albedo_color = Color(0.16, 0.20, 0.26)
	mat_platform.metallic = 0.45
	mat_platform.roughness = 0.35

	# Industrial structural steel material
	var mat_steel = StandardMaterial3D.new()
	mat_steel.albedo_color = Color(0.20, 0.24, 0.30)
	mat_steel.metallic = 0.85
	mat_steel.roughness = 0.30

	# 1. WorldEnvironment with 3D Sky Dome & Atmospheric Depth Fog
	var env_node = WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.06, 0.10, 0.18)      # Deep high-tech midnight navy
	sky_mat.sky_horizon_color = Color(0.20, 0.28, 0.38)  # Atmospheric twilight horizon
	sky_mat.ground_bottom_color = Color(0.04, 0.06, 0.08)
	sky_mat.ground_horizon_color = Color(0.14, 0.20, 0.28)
	sky_mat.sun_angle_max = 32.0
	sky.sky_material = sky_mat
	env.sky = sky

	# Ambient lighting from sky atmosphere & reflections
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.40, 0.50, 0.65)
	env.ambient_light_energy = 1.35
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	# ACES Tonemapping & Subtle Bloom
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.12

	# Atmospheric depth fog to give immense sense of scale
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.18, 0.25)
	env.fog_density = 0.006
	env.fog_aerial_perspective = 0.4
	env_node.environment = env
	root.add_child(env_node)
	env_node.owner = root

	# 2. Main Key Directional Light (Sun)
	var dir_light = DirectionalLight3D.new()
	dir_light.name = "DirectionalLight3D"
	dir_light.position = Vector3(18.0, 26.0, 22.0)
	dir_light.rotation_degrees = Vector3(-52, 40, 0)
	dir_light.shadow_enabled = true
	dir_light.shadow_bias = 0.02
	dir_light.light_energy = 1.65
	dir_light.light_color = Color(0.96, 0.98, 1.0)
	root.add_child(dir_light)
	dir_light.owner = root

	# 3. High-Bay Arena Lighting Array (9 fixtures across the 80m hangar)
	var arena_light_coords = [
		Vector3(-16.0, 11.0, -22.0),
		Vector3(0.0, 11.0, -22.0),
		Vector3(16.0, 11.0, -22.0),
		Vector3(-16.0, 11.0, 0.0),
		Vector3(0.0, 11.0, 0.0),
		Vector3(16.0, 11.0, 0.0),
		Vector3(-16.0, 11.0, 22.0),
		Vector3(0.0, 11.0, 22.0),
		Vector3(16.0, 11.0, 22.0),
	]

	var mat_light_emitter = StandardMaterial3D.new()
	mat_light_emitter.albedo_color = Color(1.0, 1.0, 1.0)
	mat_light_emitter.emission_enabled = true
	mat_light_emitter.emission = Color(0.85, 0.95, 1.0)
	mat_light_emitter.emission_energy_multiplier = 2.5

	for idx in range(arena_light_coords.size()):
		var pos = arena_light_coords[idx]

		# Physical lamp fixture housing
		var fixture = MeshInstance3D.new()
		fixture.name = "HighBayFixture_%d" % idx
		var fix_box = BoxMesh.new()
		fix_box.size = Vector3(1.2, 0.35, 1.2)
		fixture.mesh = fix_box
		fixture.position = pos
		fixture.material_override = mat_steel
		root.add_child(fixture)
		fixture.owner = root

		# Glowing emitter lens
		var lens = MeshInstance3D.new()
		lens.name = "Lens"
		var lens_box = BoxMesh.new()
		lens_box.size = Vector3(0.9, 0.05, 0.9)
		lens.mesh = lens_box
		lens.position = Vector3(0, -0.18, 0)
		lens.material_override = mat_light_emitter
		fixture.add_child(lens)
		lens.owner = root

		# Point/omni light source
		var omni = OmniLight3D.new()
		omni.name = "Light"
		omni.position = Vector3(0, -0.5, 0)
		omni.light_color = Color(0.85, 0.94, 1.0)
		omni.light_energy = 1.4
		omni.omni_range = 28.0
		omni.omni_attenuation = 1.2
		fixture.add_child(omni)
		omni.owner = root

	# Central SpotLight focused on the Robot Testing Pad
	var spot_center = SpotLight3D.new()
	spot_center.name = "SpotCenterPlatform"
	spot_center.position = Vector3(0.0, 9.5, 0.0)
	spot_center.rotation_degrees = Vector3(-90, 0, 0)
	spot_center.light_color = Color(0.90, 0.96, 1.0)
	spot_center.light_energy = 2.4
	spot_center.spot_range = 16.0
	spot_center.spot_angle = 48.0
	root.add_child(spot_center)
	spot_center.owner = root

	# 4. Expansive Laboratory Environment (80m x 80m Proving Grounds Hangar)
	var lab_env = Node3D.new()
	lab_env.name = "LaboratoryEnvironment"
	root.add_child(lab_env)
	lab_env.owner = root

	# Main Expansive Floor (80m x 80m with 1m metric grid)
	var floor_mesh = MeshInstance3D.new()
	floor_mesh.name = "FloorGrid"
	var p_mesh = PlaneMesh.new()
	p_mesh.size = Vector2(80.0, 80.0)
	floor_mesh.mesh = p_mesh
	floor_mesh.material_override = mat_floor
	lab_env.add_child(floor_mesh)
	floor_mesh.owner = root

	# Walking Track (4.2m wide, 36m long stretching from Z = +6m to Z = -30m)
	var track_mesh = MeshInstance3D.new()
	track_mesh.name = "WalkingTrack"
	var tr_plane = PlaneMesh.new()
	tr_plane.size = Vector2(4.2, 36.0)
	track_mesh.mesh = tr_plane
	track_mesh.position = Vector3(0.0, 0.005, -12.0)
	track_mesh.material_override = mat_track
	lab_env.add_child(track_mesh)
	track_mesh.owner = root

	# Hazard borders along left and right sides of walking track
	for track_side in [-2.15, 2.15]:
		var h_border = MeshInstance3D.new()
		h_border.name = "TrackHazardBorder_%s" % ("L" if track_side < 0 else "R")
		var hb_plane = PlaneMesh.new()
		hb_plane.size = Vector2(0.16, 36.0)
		h_border.mesh = hb_plane
		h_border.position = Vector3(track_side, 0.007, -12.0)
		h_border.material_override = mat_hazard
		lab_env.add_child(h_border)
		h_border.owner = root

	# Center Glowing Cyan Dashed Line along Walking Track
	var center_line = MeshInstance3D.new()
	center_line.name = "TrackCenterLine"
	var cl_mesh = PlaneMesh.new()
	cl_mesh.size = Vector2(0.12, 34.0)
	center_line.mesh = cl_mesh
	center_line.position = Vector3(0.0, 0.008, -12.0)
	var mat_cline = StandardMaterial3D.new()
	mat_cline.albedo_color = Color(0.0, 0.9, 1.0, 0.9)
	mat_cline.emission_enabled = true
	mat_cline.emission = Color(0.0, 0.8, 1.0)
	mat_cline.emission_energy_multiplier = 1.6
	center_line.material_override = mat_cline
	lab_env.add_child(center_line)
	center_line.owner = root

	# Metric Scale Markers & Physical Extruded Distance Signs every 2m from 0m to 20m
	for d in range(0, 22, 2):
		var tick = MeshInstance3D.new()
		tick.name = "MetricTick_%dm" % d
		var tick_plane = PlaneMesh.new()
		tick_plane.size = Vector2(3.6, 0.10)
		tick.mesh = tick_plane
		tick.position = Vector3(0.0, 0.009, -float(d))
		var mat_tick = StandardMaterial3D.new()
		mat_tick.albedo_color = Color(0.85, 0.92, 1.0, 0.75)
		mat_tick.emission_enabled = true
		mat_tick.emission = Color(0.0, 0.7, 1.0)
		mat_tick.emission_energy_multiplier = 0.6
		tick.material_override = mat_tick
		lab_env.add_child(tick)
		tick.owner = root

		# 3D Physical Metric Distance Marker Pillar on track edge
		var sign_pillar = MeshInstance3D.new()
		sign_pillar.name = "MetricSign_%dm" % d
		var sp_box = BoxMesh.new()
		sp_box.size = Vector3(0.20, 0.50, 0.20)
		sign_pillar.mesh = sp_box
		sign_pillar.position = Vector3(2.40, 0.25, -float(d))
		sign_pillar.material_override = mat_steel
		lab_env.add_child(sign_pillar)
		sign_pillar.owner = root

		# Glowing distance indicator cap
		var sign_cap = MeshInstance3D.new()
		sign_cap.name = "SignCap"
		var sc_box = BoxMesh.new()
		sc_box.size = Vector3(0.22, 0.06, 0.22)
		sign_cap.mesh = sc_box
		sign_cap.position = Vector3(0, 0.26, 0)
		sign_cap.material_override = mat_visor
		sign_pillar.add_child(sign_cap)
		sign_cap.owner = root

	# Robot Starting Platform (Circular illuminated platform, radius 2.4m)
	var platform = MeshInstance3D.new()
	platform.name = "StartingPlatform"
	var cyl_plat = CylinderMesh.new()
	cyl_plat.top_radius = 2.4
	cyl_plat.bottom_radius = 2.4
	cyl_plat.height = 0.025
	platform.mesh = cyl_plat
	platform.position = Vector3(0, 0.012, 0)
	platform.material_override = mat_platform
	lab_env.add_child(platform)
	platform.owner = root

	# Platform glowing concentric calibration rings
	for r_radius in [1.2, 2.38]:
		var plat_ring = MeshInstance3D.new()
		plat_ring.name = "PlatformRing_R%.1f" % r_radius
		var ring_mesh = TorusMesh.new()
		ring_mesh.inner_radius = r_radius - 0.04
		ring_mesh.outer_radius = r_radius
		ring_mesh.rings = 36
		plat_ring.mesh = ring_mesh
		plat_ring.position = Vector3(0, 0.018, 0)
		plat_ring.material_override = mat_visor
		lab_env.add_child(plat_ring)
		plat_ring.owner = root

	# Platform Calibration Crosshairs (+X and +Y axes)
	var cross_x = MeshInstance3D.new()
	cross_x.name = "PlatformCrosshairX"
	var px_box = PlaneMesh.new()
	px_box.size = Vector2(0.06, 4.4)
	cross_x.mesh = px_box
	cross_x.position = Vector3(0, 0.016, 0)
	cross_x.material_override = mat_visor
	lab_env.add_child(cross_x)
	cross_x.owner = root

	var cross_y = MeshInstance3D.new()
	cross_y.name = "PlatformCrosshairY"
	var py_box = PlaneMesh.new()
	py_box.size = Vector2(4.4, 0.06)
	cross_y.mesh = py_box
	cross_y.position = Vector3(0, 0.016, 0)
	cross_y.material_override = mat_visor
	lab_env.add_child(cross_y)
	cross_y.owner = root

	# Grand Laboratory Boundary Walls (80m wide, 12m high enclosure)
	var wall_north = MeshInstance3D.new()
	wall_north.name = "WallNorth"
	var bn_mesh = BoxMesh.new()
	bn_mesh.size = Vector3(80.0, 12.0, 1.0)
	wall_north.mesh = bn_mesh
	wall_north.position = Vector3(0, 6.0, -40.0)
	wall_north.material_override = wall_mat
	lab_env.add_child(wall_north)
	wall_north.owner = root

	var wall_south = MeshInstance3D.new()
	wall_south.name = "WallSouth"
	var bs_mesh = BoxMesh.new()
	bs_mesh.size = Vector3(80.0, 12.0, 1.0)
	wall_south.mesh = bs_mesh
	wall_south.position = Vector3(0, 6.0, 36.0)
	wall_south.material_override = wall_mat
	lab_env.add_child(wall_south)
	wall_south.owner = root

	var wall_east = MeshInstance3D.new()
	wall_east.name = "WallEast"
	var be_mesh = BoxMesh.new()
	be_mesh.size = Vector3(1.0, 12.0, 76.0)
	wall_east.mesh = be_mesh
	wall_east.position = Vector3(40.0, 6.0, -2.0)
	wall_east.material_override = wall_mat
	lab_env.add_child(wall_east)
	wall_east.owner = root

	var wall_west = MeshInstance3D.new()
	wall_west.name = "WallWest"
	var bw_mesh = BoxMesh.new()
	bw_mesh.size = Vector3(1.0, 12.0, 76.0)
	wall_west.mesh = bw_mesh
	wall_west.position = Vector3(-40.0, 6.0, -2.0)
	wall_west.material_override = wall_mat
	lab_env.add_child(wall_west)
	wall_west.owner = root

	# Vertical Architectural Pillars/Buttresses every 12m along all walls (physical 3D depth & shadows)
	for col_x in [-30.0, -15.0, 0.0, 15.0, 30.0]:
		var col_n = MeshInstance3D.new()
		col_n.name = "ColumnNorth_X%d" % int(col_x)
		var c_mesh = BoxMesh.new()
		c_mesh.size = Vector3(1.2, 12.0, 1.2)
		col_n.mesh = c_mesh
		col_n.position = Vector3(col_x, 6.0, -39.4)
		col_n.material_override = mat_steel
		lab_env.add_child(col_n)
		col_n.owner = root

		var col_s = MeshInstance3D.new()
		col_s.name = "ColumnSouth_X%d" % int(col_x)
		col_s.mesh = c_mesh
		col_s.position = Vector3(col_x, 6.0, 35.4)
		col_s.material_override = mat_steel
		lab_env.add_child(col_s)
		col_s.owner = root

	for col_z in [-28.0, -14.0, 0.0, 14.0, 28.0]:
		var col_e = MeshInstance3D.new()
		col_e.name = "ColumnEast_Z%d" % int(col_z)
		var c_mesh = BoxMesh.new()
		c_mesh.size = Vector3(1.2, 12.0, 1.2)
		col_e.mesh = c_mesh
		col_e.position = Vector3(39.4, 6.0, col_z)
		col_e.material_override = mat_steel
		lab_env.add_child(col_e)
		col_e.owner = root

		var col_w = MeshInstance3D.new()
		col_w.name = "ColumnWest_Z%d" % int(col_z)
		col_w.mesh = c_mesh
		col_w.position = Vector3(-39.4, 6.0, col_z)
		col_w.material_override = mat_steel
		lab_env.add_child(col_w)
		col_w.owner = root

	# 2nd-Floor Observation Control Gallery on North Wall (Y = 6.5m to 9.5m)
	var obs_gallery = MeshInstance3D.new()
	obs_gallery.name = "ObservationGallery"
	var og_mesh = BoxMesh.new()
	og_mesh.size = Vector3(44.0, 3.2, 2.5)
	obs_gallery.mesh = og_mesh
	obs_gallery.position = Vector3(0, 8.0, -38.6)
	obs_gallery.material_override = mat_platform
	lab_env.add_child(obs_gallery)
	obs_gallery.owner = root

	# Observation Tinted Glass Viewing Windows
	var obs_glass = MeshInstance3D.new()
	obs_glass.name = "ObservationGlass"
	var gl_mesh = BoxMesh.new()
	gl_mesh.size = Vector3(42.0, 2.2, 0.1)
	obs_glass.mesh = gl_mesh
	obs_glass.position = Vector3(0, 8.0, -37.3)
	var mat_glass = StandardMaterial3D.new()
	mat_glass.albedo_color = Color(0.1, 0.3, 0.5, 0.6)
	mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_glass.metallic = 0.9
	mat_glass.roughness = 0.1
	obs_glass.material_override = mat_glass
	lab_env.add_child(obs_glass)
	obs_glass.owner = root

	# Glowing Terminal Monitors inside Observation Control Room
	for mon_idx in range(-16, 17, 8):
		var monitor = MeshInstance3D.new()
		monitor.name = "ControlMonitor_%d" % mon_idx
		var m_box = BoxMesh.new()
		m_box.size = Vector3(2.4, 1.2, 0.1)
		monitor.mesh = m_box
		monitor.position = Vector3(float(mon_idx), 8.2, -38.4)
		var mat_mon = StandardMaterial3D.new()
		mat_mon.albedo_color = Color(0.0, 0.8, 1.0)
		mat_mon.emission_enabled = true
		mat_mon.emission = Color(0.0, 0.7, 1.0) if mon_idx % 2 == 0 else Color(0.1, 0.9, 0.4)
		mat_mon.emission_energy_multiplier = 1.8
		monitor.material_override = mat_mon
		lab_env.add_child(monitor)
		monitor.owner = root

	# Illuminated Facility Signage over Gallery: "HUMANOID ROBOTICS PROVING GROUNDS - BAY 01"
	var fac_sign = MeshInstance3D.new()
	fac_sign.name = "FacilitySignage"
	var fs_box = BoxMesh.new()
	fs_box.size = Vector3(32.0, 0.8, 0.15)
	fac_sign.mesh = fs_box
	fac_sign.position = Vector3(0, 10.2, -39.2)
	var mat_sign = StandardMaterial3D.new()
	mat_sign.albedo_color = Color(0.05, 0.08, 0.12)
	mat_sign.emission_enabled = true
	mat_sign.emission = Color(0.0, 0.75, 1.0)
	mat_sign.emission_energy_multiplier = 1.2
	fac_sign.material_override = mat_sign
	lab_env.add_child(fac_sign)
	fac_sign.owner = root

	# Accent Cyan Neon Light Strips along all 4 walls
	var strip_n = MeshInstance3D.new()
	strip_n.name = "StripNorth"
	var sn_mesh = BoxMesh.new()
	sn_mesh.size = Vector3(76.0, 0.12, 0.15)
	strip_n.mesh = sn_mesh
	strip_n.position = Vector3(0, 6.2, -39.3)
	strip_n.material_override = mat_visor
	lab_env.add_child(strip_n)
	strip_n.owner = root

	var strip_s = MeshInstance3D.new()
	strip_s.name = "StripSouth"
	var ss_mesh = BoxMesh.new()
	ss_mesh.size = Vector3(76.0, 0.12, 0.15)
	strip_s.mesh = ss_mesh
	strip_s.position = Vector3(0, 6.2, 35.3)
	strip_s.material_override = mat_visor
	lab_env.add_child(strip_s)
	strip_s.owner = root

	var strip_e = MeshInstance3D.new()
	strip_e.name = "StripEast"
	var se_mesh = BoxMesh.new()
	se_mesh.size = Vector3(0.15, 0.12, 72.0)
	strip_e.mesh = se_mesh
	strip_e.position = Vector3(39.3, 6.2, -2.0)
	strip_e.material_override = mat_visor
	lab_env.add_child(strip_e)
	strip_e.owner = root

	var strip_w = MeshInstance3D.new()
	strip_w.name = "StripWest"
	var sw_mesh = BoxMesh.new()
	sw_mesh.size = Vector3(0.15, 0.12, 72.0)
	strip_w.mesh = sw_mesh
	strip_w.position = Vector3(-39.3, 6.2, -2.0)
	strip_w.material_override = mat_visor
	lab_env.add_child(strip_w)
	strip_w.owner = root

	# Massive Overhead Ceiling Roof Trusses spanning across the hangar at Y = 11.5m
	for tz in [-28.0, -14.0, 0.0, 14.0, 28.0]:
		var truss = MeshInstance3D.new()
		truss.name = "CeilingTruss_Z%d" % int(tz)
		var tr_mesh = BoxMesh.new()
		tr_mesh.size = Vector3(79.0, 0.45, 0.45)
		truss.mesh = tr_mesh
		truss.position = Vector3(0, 11.5, tz)
		truss.material_override = mat_steel
		lab_env.add_child(truss)
		truss.owner = root

	# Overhead Industrial Yellow Gantry Crane spanning at Y = 11.0m
	var gantry_crane = MeshInstance3D.new()
	gantry_crane.name = "OverheadGantryCrane"
	var gc_mesh = BoxMesh.new()
	gc_mesh.size = Vector3(78.0, 0.70, 1.4)
	gantry_crane.mesh = gc_mesh
	gantry_crane.position = Vector3(0, 11.0, -8.0)
	var mat_crane = StandardMaterial3D.new()
	mat_crane.albedo_color = Color(0.95, 0.75, 0.1)
	mat_crane.metallic = 0.7
	mat_crane.roughness = 0.3
	gantry_crane.material_override = mat_crane
	lab_env.add_child(gantry_crane)
	gantry_crane.owner = root

	# --- TESTING PROVING ZONES ---

	# ZONE C (Left Side, X = -10m to -24m): Obstacle & Slalom Proving Ground
	# Demarcated Zone C Floor Boundary Outline
	var zone_c_box = MeshInstance3D.new()
	zone_c_box.name = "ZoneC_FloorPerimeter"
	var zc_mesh = PlaneMesh.new()
	zc_mesh.size = Vector2(14.0, 22.0)
	zone_c_box.mesh = zc_mesh
	zone_c_box.position = Vector3(-16.0, 0.006, -8.0)
	var mat_zc = StandardMaterial3D.new()
	mat_zc.albedo_color = Color(0.12, 0.16, 0.22, 0.6)
	mat_zc.roughness = 0.6
	zone_c_box.material_override = mat_zc
	lab_env.add_child(zone_c_box)
	zone_c_box.owner = root

	# Zone C Heavy Safety Crash Barrier with Hazard Chevrons
	var barrier_mesh = MeshInstance3D.new()
	barrier_mesh.name = "ZoneC_HeavyBarrier"
	var bar_box = BoxMesh.new()
	bar_box.size = Vector3(0.40, 0.85, 3.8)
	barrier_mesh.mesh = bar_box
	barrier_mesh.position = Vector3(-12.0, 0.425, -6.0)
	barrier_mesh.material_override = mat_hazard
	lab_env.add_child(barrier_mesh)
	barrier_mesh.owner = root

	# Zone C Static Test Pylons / Cylinders
	for cyl_idx in [0, 1]:
		var cyl_inst = MeshInstance3D.new()
		cyl_inst.name = "ZoneC_TestPylon_%d" % cyl_idx
		var cy_mesh = CylinderMesh.new()
		cy_mesh.top_radius = 0.35
		cy_mesh.bottom_radius = 0.35
		cy_mesh.height = 1.10
		cyl_inst.mesh = cy_mesh
		cyl_inst.position = Vector3(-18.0, 0.55, -4.0 - float(cyl_idx) * 6.0)
		var mat_pylon = StandardMaterial3D.new()
		mat_pylon.albedo_color = Color(0.95, 0.45, 0.10)
		mat_pylon.metallic = 0.4
		mat_pylon.roughness = 0.3
		cyl_inst.material_override = mat_pylon
		lab_env.add_child(cyl_inst)
		cyl_inst.owner = root

	# ZONE D (Right Side, X = +10m to +24m): Terrain & Incline Proving Grounds
	# Demarcated Zone D Floor Boundary Outline
	var zone_d_box = MeshInstance3D.new()
	zone_d_box.name = "ZoneD_FloorPerimeter"
	var zd_mesh = PlaneMesh.new()
	zd_mesh.size = Vector2(14.0, 22.0)
	zone_d_box.mesh = zd_mesh
	zone_d_box.position = Vector3(16.0, 0.006, -8.0)
	var mat_zd = StandardMaterial3D.new()
	mat_zd.albedo_color = Color(0.12, 0.16, 0.22, 0.6)
	mat_zd.roughness = 0.6
	zone_d_box.material_override = mat_zd
	lab_env.add_child(zone_d_box)
	zone_d_box.owner = root

	# 1. Gentle 5° Terrain Incline Approach Ramp
	var ramp_mesh = MeshInstance3D.new()
	ramp_mesh.name = "ZoneD_GentleRamp"
	var r_box = BoxMesh.new()
	r_box.size = Vector3(1.8, 0.22, 3.8)
	ramp_mesh.mesh = r_box
	ramp_mesh.position = Vector3(12.0, 0.15, -4.0)
	ramp_mesh.rotation_degrees = Vector3(5.0, 0, 0)
	var mat_ramp = StandardMaterial3D.new()
	mat_ramp.albedo_color = Color(0.22, 0.55, 0.78)
	mat_ramp.roughness = 0.35
	ramp_mesh.material_override = mat_ramp
	lab_env.add_child(ramp_mesh)
	ramp_mesh.owner = root

	# Ramp hazard stripe border
	var ramp_stripe = MeshInstance3D.new()
	ramp_stripe.name = "ZoneD_RampHazardBorder"
	var rs_box = BoxMesh.new()
	rs_box.size = Vector3(1.85, 0.02, 3.85)
	ramp_stripe.mesh = rs_box
	ramp_stripe.position = Vector3(12.0, 0.015, -4.0)
	ramp_stripe.rotation_degrees = Vector3(5.0, 0, 0)
	ramp_stripe.material_override = mat_hazard
	lab_env.add_child(ramp_stripe)
	ramp_stripe.owner = root

	# 2. Steep 12° Incline Ramp
	var steep_ramp = MeshInstance3D.new()
	steep_ramp.name = "ZoneD_SteepRamp"
	var sr_box = BoxMesh.new()
	sr_box.size = Vector3(1.6, 0.25, 3.2)
	steep_ramp.mesh = sr_box
	steep_ramp.position = Vector3(18.0, 0.32, -4.0)
	steep_ramp.rotation_degrees = Vector3(12.0, 0, 0)
	steep_ramp.material_override = mat_platform
	lab_env.add_child(steep_ramp)
	steep_ramp.owner = root

	# 3. Progressive 4-Step Industrial Staircase
	for s_idx in range(4):
		var step_inst = MeshInstance3D.new()
		step_inst.name = "ZoneD_Stair_%d" % s_idx
		var step_box = BoxMesh.new()
		var s_h = 0.08 * (s_idx + 1)
		step_box.size = Vector3(1.6, s_h, 0.42)
		step_inst.mesh = step_box
		step_inst.position = Vector3(15.0, s_h * 0.5, -9.0 - float(s_idx) * 0.42)
		step_inst.material_override = mat_steel
		lab_env.add_child(step_inst)
		step_inst.owner = root

	# 4. Elevated Proving Ground Observation Pad (3.5m x 3.5m, height 0.6m)
	var elev_pad = MeshInstance3D.new()
	elev_pad.name = "ZoneD_ElevatedPad"
	var ep_box = BoxMesh.new()
	ep_box.size = Vector3(3.5, 0.60, 3.5)
	elev_pad.mesh = ep_box
	elev_pad.position = Vector3(15.0, 0.30, -14.5)
	elev_pad.material_override = mat_platform
	lab_env.add_child(elev_pad)
	elev_pad.owner = root

	# Telemetry Data Server Racks along East Wall with Status LEDs
	for rk_idx in range(4):
		var rack = MeshInstance3D.new()
		rack.name = "ServerRack_%d" % rk_idx
		var rk_box = BoxMesh.new()
		rk_box.size = Vector3(0.9, 2.4, 0.9)
		rack.mesh = rk_box
		rack.position = Vector3(38.8, 1.2, -15.0 + float(rk_idx) * 3.0)
		rack.material_override = mat_steel
		lab_env.add_child(rack)
		rack.owner = root

		# Status LED bar
		var led = MeshInstance3D.new()
		led.name = "StatusLED"
		var led_box = BoxMesh.new()
		led_box.size = Vector3(0.05, 0.12, 0.6)
		led.mesh = led_box
		led.position = Vector3(-0.46, 0.6, 0)
		var mat_led = StandardMaterial3D.new()
		mat_led.albedo_color = Color(0.0, 0.9, 0.5)
		mat_led.emission_enabled = true
		mat_led.emission = Color(0.0, 0.9, 0.5) if rk_idx % 2 == 0 else Color(0.0, 0.8, 1.0)
		mat_led.emission_energy_multiplier = 2.0
		led.material_override = mat_led
		rack.add_child(led)
		led.owner = root

	# Industrial Yellow Safety Guard Railings along perimeter
	for rail_x in [-24.0, 24.0]:
		var railing = MeshInstance3D.new()
		railing.name = "SafetyRail_%s" % ("L" if rail_x < 0 else "R")
		var rl_box = BoxMesh.new()
		rl_box.size = Vector3(0.12, 1.0, 48.0)
		railing.mesh = rl_box
		railing.position = Vector3(rail_x, 0.50, -6.0)
		var mat_rail = StandardMaterial3D.new()
		mat_rail.albedo_color = Color(0.95, 0.80, 0.10)
		mat_rail.metallic = 0.5
		mat_rail.roughness = 0.3
		railing.material_override = mat_rail
		lab_env.add_child(railing)
		railing.owner = root

	# ZONE E (South-East Proving Grounds, X = +12m to +24m, Z = +8m to +20m):
	# Robotic Manipulation & Pick-and-Place Testing Station
	var zone_e_floor = MeshInstance3D.new()
	zone_e_floor.name = "ZoneE_FloorPerimeter"
	var ze_mesh = PlaneMesh.new()
	ze_mesh.size = Vector2(12.0, 12.0)
	zone_e_floor.mesh = ze_mesh
	zone_e_floor.position = Vector3(16.0, 0.007, 12.0)
	var mat_ze = StandardMaterial3D.new()
	mat_ze.albedo_color = Color(0.10, 0.18, 0.22, 0.8)
	mat_ze.roughness = 0.5
	zone_e_floor.material_override = mat_ze
	lab_env.add_child(zone_e_floor)
	zone_e_floor.owner = root

	# Heavy Steel Industrial Manipulation Table
	var table_top = MeshInstance3D.new()
	table_top.name = "ZoneE_WorkstationTable"
	var tt_mesh = BoxMesh.new()
	tt_mesh.size = Vector3(4.0, 0.15, 2.2)
	table_top.mesh = tt_mesh
	table_top.position = Vector3(16.0, 0.85, 12.0)
	table_top.material_override = mat_platform
	lab_env.add_child(table_top)
	table_top.owner = root

	# Workstation Legs
	for leg_dx in [-1.8, 1.8]:
		for leg_dz in [-0.9, 0.9]:
			var leg = MeshInstance3D.new()
			leg.name = "ZoneE_TableLeg_%d_%d" % [int(leg_dx * 10), int(leg_dz * 10)]
			var leg_mesh = BoxMesh.new()
			leg_mesh.size = Vector3(0.12, 0.85, 0.12)
			leg.mesh = leg_mesh
			leg.position = Vector3(16.0 + leg_dx, 0.425, 12.0 + leg_dz)
			leg.material_override = mat_steel
			lab_env.add_child(leg)
			leg.owner = root

	# Overhead Tool Gantry / Indicator Bar
	var gantry_bar = MeshInstance3D.new()
	gantry_bar.name = "ZoneE_ToolGantry"
	var gb_mesh = BoxMesh.new()
	gb_mesh.size = Vector3(3.6, 0.08, 0.08)
	gantry_bar.mesh = gb_mesh
	gantry_bar.position = Vector3(16.0, 2.2, 12.0)
	var mat_gantry = StandardMaterial3D.new()
	mat_gantry.albedo_color = Color(0.0, 0.85, 1.0)
	mat_gantry.emission_enabled = true
	mat_gantry.emission = Color(0.0, 0.85, 1.0)
	mat_gantry.emission_energy_multiplier = 1.5
	gantry_bar.material_override = mat_gantry
	lab_env.add_child(gantry_bar)
	gantry_bar.owner = root

	# 5. CameraController
	var cam_ctrl = Node3D.new()
	cam_ctrl.name = "CameraController"
	cam_ctrl.set_script(cam_script)
	root.add_child(cam_ctrl)
	cam_ctrl.owner = root

	var cam3d = Camera3D.new()
	cam3d.name = "Camera3D"
	cam3d.current = true
	cam3d.fov = 52.0
	cam3d.position = Vector3.ZERO
	cam_ctrl.add_child(cam3d)
	cam3d.owner = root

	# 6. XR Setup
	var xr_origin = Node3D.new()
	xr_origin.name = "XROrigin3D"
	xr_origin.set_script(xr_script)
	root.add_child(xr_origin)
	xr_origin.owner = root

	var xr_cam = XRCamera3D.new()
	xr_cam.name = "XRCamera3D"
	xr_cam.current = false
	xr_origin.add_child(xr_cam)
	xr_cam.owner = root

	var left_ctrl = XRController3D.new()
	left_ctrl.name = "LeftController"
	left_ctrl.tracker = "left_hand"
	xr_origin.add_child(left_ctrl)
	left_ctrl.owner = root

	var right_ctrl = XRController3D.new()
	right_ctrl.name = "RightController"
	right_ctrl.tracker = "right_hand"
	xr_origin.add_child(right_ctrl)
	right_ctrl.owner = root

	# 7. ObstacleManager
	var obs_mgr = Node3D.new()
	obs_mgr.name = "ObstacleManager"
	obs_mgr.set_script(obs_script)
	root.add_child(obs_mgr)
	obs_mgr.owner = root

	# 8. RobotVisualizer
	var rob_vis = Node3D.new()
	rob_vis.name = "RobotVisualizer"
	rob_vis.set_script(rob_script)
	root.add_child(rob_vis)
	rob_vis.owner = root

	var sensor_rays = Node3D.new()
	sensor_rays.name = "SensorRays"
	rob_vis.add_child(sensor_rays)
	sensor_rays.owner = root

	var links_container = Node3D.new()
	links_container.name = "Links"
	rob_vis.add_child(links_container)
	links_container.owner = root

	# 1. Torso
	var torso_node = MeshInstance3D.new()
	torso_node.name = "torso"
	var torso_mesh = BoxMesh.new()
	torso_mesh.size = Vector3(0.24, 0.42, 0.26)
	torso_node.mesh = torso_mesh
	torso_node.material_override = mat_torso
	torso_node.position = Vector3(0, 0.83, 0)
	links_container.add_child(torso_node)
	torso_node.owner = root

	# Chest telemetry accent strip
	var chest_strip = MeshInstance3D.new()
	chest_strip.name = "ChestAccent"
	var cs_mesh = BoxMesh.new()
	cs_mesh.size = Vector3(0.12, 0.03, 0.01)
	chest_strip.mesh = cs_mesh
	chest_strip.position = Vector3(0, 0.08, -0.135)
	chest_strip.material_override = mat_visor
	torso_node.add_child(chest_strip)
	chest_strip.owner = root

	# Chest Glowing Core Arc Reactor
	var chest_core = MeshInstance3D.new()
	chest_core.name = "ChestReactorCore"
	var ccore_mesh = CylinderMesh.new()
	ccore_mesh.top_radius = 0.045
	ccore_mesh.bottom_radius = 0.045
	ccore_mesh.height = 0.015
	chest_core.mesh = ccore_mesh
	chest_core.rotation_degrees = Vector3(90, 0, 0)
	chest_core.position = Vector3(0, 0.01, -0.135)
	chest_core.material_override = mat_visor
	torso_node.add_child(chest_core)
	chest_core.owner = root

	# 2. Head with Visor
	var head_node = Node3D.new()
	head_node.name = "head"
	head_node.position = Vector3(0, 1.11, 0)
	links_container.add_child(head_node)
	head_node.owner = root

	var head_mesh_inst = MeshInstance3D.new()
	head_mesh_inst.name = "HeadMesh"
	var head_mesh = SphereMesh.new()
	head_mesh.radius = 0.11
	head_mesh.height = 0.22
	head_mesh_inst.mesh = head_mesh
	head_mesh_inst.material_override = mat_limbs
	head_mesh_inst.position = Vector3.ZERO
	head_node.add_child(head_mesh_inst)
	head_mesh_inst.owner = root

	var visor_mesh_inst = MeshInstance3D.new()
	visor_mesh_inst.name = "VisorMesh"
	var visor_mesh = BoxMesh.new()
	visor_mesh.size = Vector3(0.13, 0.045, 0.035)
	visor_mesh_inst.mesh = visor_mesh
	visor_mesh_inst.material_override = mat_visor
	visor_mesh_inst.position = Vector3(0, 0.01, -0.10)
	head_node.add_child(visor_mesh_inst)
	visor_mesh_inst.owner = root

	# Head Sensor Fin Antennas (Left and Right)
	for s_side in [-0.115, 0.115]:
		var fin = MeshInstance3D.new()
		fin.name = "SensorFin_%s" % ("L" if s_side < 0 else "R")
		var fin_mesh = BoxMesh.new()
		fin_mesh.size = Vector3(0.015, 0.07, 0.05)
		fin.mesh = fin_mesh
		fin.position = Vector3(s_side, 0.02, 0.0)
		fin.material_override = mat_visor
		head_node.add_child(fin)
		fin.owner = root

	# Limb definitions: [name, radius, height, material, initial_pos]
	var limb_defs = [
		["left_upper_arm", 0.045, 0.24, mat_limbs, Vector3(-0.17, 0.86, 0)],
		["left_forearm", 0.04, 0.22, mat_limbs, Vector3(-0.17, 0.65, 0)],
		["right_upper_arm", 0.045, 0.24, mat_limbs, Vector3(0.17, 0.86, 0)],
		["right_forearm", 0.04, 0.22, mat_limbs, Vector3(0.17, 0.65, 0)],
		["left_thigh", 0.055, 0.32, mat_limbs, Vector3(-0.10, 0.48, 0)],
		["left_shin", 0.05, 0.30, mat_limbs, Vector3(-0.10, 0.19, 0)],
		["right_thigh", 0.055, 0.32, mat_limbs, Vector3(0.10, 0.48, 0)],
		["right_shin", 0.05, 0.30, mat_limbs, Vector3(0.10, 0.19, 0)],
	]

	for l_def in limb_defs:
		var l_node = MeshInstance3D.new()
		l_node.name = l_def[0]
		var c_mesh = CylinderMesh.new()
		c_mesh.top_radius = l_def[1]
		c_mesh.bottom_radius = l_def[1]
		c_mesh.height = l_def[2]
		l_node.mesh = c_mesh
		l_node.material_override = l_def[3]
		l_node.position = l_def[4]
		links_container.add_child(l_node)
		l_node.owner = root

		# Glowing Joint Articulation Ring on each limb segment
		var j_ring = MeshInstance3D.new()
		j_ring.name = "JointRing_" + l_def[0]
		var jr_mesh = TorusMesh.new()
		jr_mesh.inner_radius = l_def[1] * 0.95
		jr_mesh.outer_radius = l_def[1] * 1.15
		jr_mesh.rings = 16
		j_ring.mesh = jr_mesh
		j_ring.position = Vector3(0, l_def[2] * 0.45, 0)
		j_ring.material_override = mat_joints
		l_node.add_child(j_ring)
		j_ring.owner = root

	# Robotic Hands (Attached to Forearms)
	for fa_name in ["left_forearm", "right_forearm"]:
		var fa_node = links_container.get_node_or_null(fa_name)
		if fa_node:
			var hand_node = MeshInstance3D.new()
			hand_node.name = fa_name.replace("forearm", "hand")
			var h_box = BoxMesh.new()
			h_box.size = Vector3(0.045, 0.075, 0.075)
			hand_node.mesh = h_box
			hand_node.position = Vector3(0, -0.13, 0)
			hand_node.material_override = mat_torso
			fa_node.add_child(hand_node)
			hand_node.owner = root

			# Knuckle grip finger accent
			var fin_acc = MeshInstance3D.new()
			fin_acc.name = "Fingers"
			var f_box = BoxMesh.new()
			f_box.size = Vector3(0.04, 0.03, 0.02)
			fin_acc.mesh = f_box
			fin_acc.position = Vector3(0, -0.045, -0.03)
			fin_acc.material_override = mat_joints
			hand_node.add_child(fin_acc)
			fin_acc.owner = root

	# Feet (BoxMeshes with distinct sole contact pads and glowing trim)
	var foot_positions = {
		"left_foot": Vector3(-0.10, 0.03, -0.03),
		"right_foot": Vector3(0.10, 0.03, -0.03)
	}
	for foot_name in ["left_foot", "right_foot"]:
		var f_node = MeshInstance3D.new()
		f_node.name = foot_name
		var f_mesh = BoxMesh.new()
		f_mesh.size = Vector3(0.15, 0.045, 0.26)
		f_node.mesh = f_mesh
		f_node.material_override = mat_torso
		f_node.position = foot_positions[foot_name]
		links_container.add_child(f_node)
		f_node.owner = root

		# Sole Tread Contact Pad
		var sole_pad = MeshInstance3D.new()
		sole_pad.name = "SoleTreadPad"
		var sp_mesh = BoxMesh.new()
		sp_mesh.size = Vector3(0.14, 0.012, 0.24)
		sole_pad.mesh = sp_mesh
		sole_pad.position = Vector3(0, -0.022, 0)
		sole_pad.material_override = mat_joints
		f_node.add_child(sole_pad)
		sole_pad.owner = root

	# 9. NetworkClient
	var net_node = Node.new()
	net_node.name = "NetworkClient"
	net_node.set_script(net_script)
	root.add_child(net_node)
	net_node.owner = root

	# 10. User Interface (UI)
	var ui_node = Control.new()
	ui_node.name = "UI"
	ui_node.set_script(ui_script)
	ui_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(ui_node)
	ui_node.owner = root

	ui_node.set("network_client", net_node)
	ui_node.set("camera_controller", cam_ctrl)
	ui_node.set("robot_visualizer", rob_vis)
	xr_origin.set("xr_origin", xr_origin)
	xr_origin.set("desktop_camera", cam3d)

	# --- Common Theme StyleBoxes ---
	var style_panel = StyleBoxFlat.new()
	style_panel.bg_color = Color(0.08, 0.10, 0.14, 0.94)
	style_panel.border_color = Color(0.18, 0.26, 0.38)
	style_panel.set_border_width_all(1)
	style_panel.set_corner_radius_all(6)

	var style_card = StyleBoxFlat.new()
	style_card.bg_color = Color(0.11, 0.14, 0.20, 0.9)
	style_card.border_color = Color(0.20, 0.30, 0.44)
	style_card.set_border_width_all(1)
	style_card.set_corner_radius_all(4)

	# --- TOP NAVIGATION BAR ---
	var top_bar = PanelContainer.new()
	top_bar.name = "TopBar"
	top_bar.set_anchor_and_offset(SIDE_LEFT, 0, 0)
	top_bar.set_anchor_and_offset(SIDE_RIGHT, 1, 0)
	top_bar.set_anchor_and_offset(SIDE_TOP, 0, 0)
	top_bar.set_anchor_and_offset(SIDE_BOTTOM, 0, 48)

	var top_style = StyleBoxFlat.new()
	top_style.bg_color = Color(0.06, 0.08, 0.12, 0.98)
	top_style.border_color = Color(0.0, 0.75, 1.0, 0.5)
	top_style.border_width_bottom = 2
	top_bar.add_theme_stylebox_override("panel", top_style)
	ui_node.add_child(top_bar)
	top_bar.owner = root

	var top_hbox = HBoxContainer.new()
	top_hbox.name = "TopHBox"
	top_hbox.add_theme_constant_override("separation", 10)
	top_bar.add_child(top_hbox)
	top_hbox.owner = root

	var lbl_logo = Label.new()
	lbl_logo.text = " 🤖 VR HUMANOID "
	lbl_logo.add_theme_font_size_override("font_size", 15)
	lbl_logo.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	top_hbox.add_child(lbl_logo)
	lbl_logo.owner = root

	# Tab Buttons
	var tab_names_labels = [
		["BtnTabSim", "Simulation"],
		["BtnTabControl", "Robot Control"],
		["BtnTabBalance", "Balance"],
		["BtnTabSensors", "Sensors"],
		["BtnTabAnalytics", "Analytics"],
		["BtnTabExperiments", "Experiments"],
		["BtnTabSettings", "Settings"]
	]
	for t_pair in tab_names_labels:
		var btn = Button.new()
		btn.name = t_pair[0]
		btn.text = t_pair[1]
		top_hbox.add_child(btn)
		btn.owner = root

	var top_spacer = Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hbox.add_child(top_spacer)
	top_spacer.owner = root

	# Status Pills
	var lbl_conn = Label.new()
	lbl_conn.name = "LblConnection"
	lbl_conn.text = "○ CONNECTING..."
	lbl_conn.add_theme_font_size_override("font_size", 12)
	lbl_conn.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
	top_hbox.add_child(lbl_conn)
	lbl_conn.owner = root

	var lbl_phys = Label.new()
	lbl_phys.name = "LblPhysicsStatus"
	lbl_phys.text = "Physics: 60 Hz"
	lbl_phys.add_theme_font_size_override("font_size", 12)
	lbl_phys.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	top_hbox.add_child(lbl_phys)
	lbl_phys.owner = root

	var lbl_xr = Label.new()
	lbl_xr.name = "LblXR"
	lbl_xr.text = "XR: Desktop Mode"
	lbl_xr.add_theme_font_size_override("font_size", 12)
	lbl_xr.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	top_hbox.add_child(lbl_xr)
	lbl_xr.owner = root

	# Camera Presets OptionButton
	var opt_cam = OptionButton.new()
	opt_cam.name = "OptCamera"
	top_hbox.add_child(opt_cam)
	opt_cam.owner = root

	var btn_res_cam = Button.new()
	btn_res_cam.name = "BtnResetCam"
	btn_res_cam.text = "Reset Cam"
	top_hbox.add_child(btn_res_cam)
	btn_res_cam.owner = root

	# --- MAIN CONTENT AREA ---
	var content_area = Control.new()
	content_area.name = "ContentArea"
	content_area.set_anchor_and_offset(SIDE_LEFT, 0, 0)
	content_area.set_anchor_and_offset(SIDE_RIGHT, 1, 0)
	content_area.set_anchor_and_offset(SIDE_TOP, 0, 48)
	content_area.set_anchor_and_offset(SIDE_BOTTOM, 1, 0)
	content_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_node.add_child(content_area)
	content_area.owner = root

	# =========================================================================
	# TAB PANEL 0: SIMULATION (HUD Overlays)
	# =========================================================================
	var tab_sim = Control.new()
	tab_sim.name = "TabPanel_Sim"
	tab_sim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab_sim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_area.add_child(tab_sim)
	tab_sim.owner = root

	# Left Panel Toggle Button
	var btn_tog_l = Button.new()
	btn_tog_l.name = "BtnToggleLeft"
	btn_tog_l.text = "◀"
	btn_tog_l.position = Vector2(10, 10)
	btn_tog_l.custom_minimum_size = Vector2(28, 28)
	tab_sim.add_child(btn_tog_l)
	btn_tog_l.owner = root

	# Left Panel
	var left_p = PanelContainer.new()
	left_p.name = "LeftPanel"
	left_p.set_anchor_and_offset(SIDE_LEFT, 0, 45)
	left_p.set_anchor_and_offset(SIDE_TOP, 0, 10)
	left_p.set_anchor_and_offset(SIDE_RIGHT, 0, 385)
	left_p.set_anchor_and_offset(SIDE_BOTTOM, 1, -170)
	left_p.add_theme_stylebox_override("panel", style_panel)
	tab_sim.add_child(left_p)
	left_p.owner = root

	var left_scroll = ScrollContainer.new()
	left_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_p.add_child(left_scroll)
	left_scroll.owner = root

	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 10)
	left_scroll.add_child(left_vbox)
	left_vbox.owner = root

	# Status Card
	var card_status = PanelContainer.new()
	card_status.add_theme_stylebox_override("panel", style_card)
	left_vbox.add_child(card_status)
	card_status.owner = root

	var vbox_sc = VBoxContainer.new()
	vbox_sc.add_theme_constant_override("separation", 3)
	card_status.add_child(vbox_sc)
	vbox_sc.owner = root

	var lbl_sc_hdr = Label.new()
	lbl_sc_hdr.text = "ROBOT STATUS DASHBOARD"
	lbl_sc_hdr.add_theme_font_size_override("font_size", 13)
	lbl_sc_hdr.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vbox_sc.add_child(lbl_sc_hdr)
	lbl_sc_hdr.owner = root

	var sim_labels = [
		["LblSimState", "State: STANDING"],
		["LblSimBalance", "Balance: STABLE"],
		["LblSimFallCount", "Fall Incidents: 0"],
		["LblSimRPY", "R: +0.0° | P: +0.0° | Y: +0.0°"],
		["LblSimPos", "Pos: (0.00, 0.00, 0.85)m"],
		["LblSimWalkPhase", "Gait: STAND / IDLE"],
		["LblSimSensors", "Sensors: F: 3.50m | L: 3.50m | R: 3.50m"],
		["LblSimAvoidance", "Avoidance: CLEAR"],
		["LblSimCollisions", "Collisions: 0"]
	]
	for sl in sim_labels:
		var l = Label.new()
		l.name = sl[0]
		l.text = sl[1]
		l.add_theme_font_size_override("font_size", 11)
		vbox_sc.add_child(l)
		l.owner = root

	# Quick Control Card
	var card_ctrl = PanelContainer.new()
	card_ctrl.add_theme_stylebox_override("panel", style_card)
	left_vbox.add_child(card_ctrl)
	card_ctrl.owner = root

	var vbox_qc = VBoxContainer.new()
	vbox_qc.add_theme_constant_override("separation", 5)
	card_ctrl.add_child(vbox_qc)
	vbox_qc.owner = root

	var lbl_qc_hdr = Label.new()
	lbl_qc_hdr.text = "QUICK CONTROL"
	lbl_qc_hdr.add_theme_font_size_override("font_size", 13)
	lbl_qc_hdr.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vbox_qc.add_child(lbl_qc_hdr)
	lbl_qc_hdr.owner = root

	var hbox_qc1 = HBoxContainer.new()
	vbox_qc.add_child(hbox_qc1)
	hbox_qc1.owner = root

	var btn_w = Button.new()
	btn_w.name = "BtnSimWalk"
	btn_w.text = "▶ Walk"
	btn_w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_qc1.add_child(btn_w)
	btn_w.owner = root

	var btn_s = Button.new()
	btn_s.name = "BtnSimStop"
	btn_s.text = "⏹ Stop"
	btn_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_qc1.add_child(btn_s)
	btn_s.owner = root

	var hbox_qc2 = HBoxContainer.new()
	vbox_qc.add_child(hbox_qc2)
	hbox_qc2.owner = root

	var btn_st = Button.new()
	btn_st.name = "BtnSimStand"
	btn_st.text = "⚖ Stand"
	btn_st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_qc2.add_child(btn_st)
	btn_st.owner = root

	var btn_r = Button.new()
	btn_r.name = "BtnSimReset"
	btn_r.text = "↺ Reset Posture"
	btn_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_qc2.add_child(btn_r)
	btn_r.owner = root

	# Arena Navigation D-Pad Controls
	var lbl_steer = Label.new()
	lbl_steer.text = "ARENA NAVIGATION [WASD]"
	lbl_steer.add_theme_font_size_override("font_size", 11)
	lbl_steer.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	vbox_qc.add_child(lbl_steer)
	lbl_steer.owner = root

	var hbox_qnav1 = HBoxContainer.new()
	vbox_qc.add_child(hbox_qnav1)
	hbox_qnav1.owner = root

	var btn_q_fwd = Button.new()
	btn_q_fwd.name = "BtnQuickFwd"
	btn_q_fwd.text = "▲ Forward [W]"
	btn_q_fwd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_qnav1.add_child(btn_q_fwd)
	btn_q_fwd.owner = root

	var btn_q_back = Button.new()
	btn_q_back.name = "BtnQuickBack"
	btn_q_back.text = "▼ Backward [S]"
	btn_q_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_qnav1.add_child(btn_q_back)
	btn_q_back.owner = root

	var hbox_qnav2 = HBoxContainer.new()
	vbox_qc.add_child(hbox_qnav2)
	hbox_qnav2.owner = root

	var btn_q_left = Button.new()
	btn_q_left.name = "BtnQuickLeft"
	btn_q_left.text = "◀ Turn Left [A]"
	btn_q_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_qnav2.add_child(btn_q_left)
	btn_q_left.owner = root

	var btn_q_right = Button.new()
	btn_q_right.name = "BtnQuickRight"
	btn_q_right.text = "▶ Turn Right [D]"
	btn_q_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_qnav2.add_child(btn_q_right)
	btn_q_right.owner = root

	# Disturbance Card
	var card_dist = PanelContainer.new()
	card_dist.add_theme_stylebox_override("panel", style_card)
	left_vbox.add_child(card_dist)
	card_dist.owner = root

	var vbox_dist = VBoxContainer.new()
	vbox_dist.add_theme_constant_override("separation", 5)
	card_dist.add_child(vbox_dist)
	vbox_dist.owner = root

	var lbl_dist_hdr = Label.new()
	lbl_dist_hdr.text = "EXTERNAL DISTURBANCE"
	lbl_dist_hdr.add_theme_font_size_override("font_size", 13)
	lbl_dist_hdr.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vbox_dist.add_child(lbl_dist_hdr)
	lbl_dist_hdr.owner = root

	var hbox_dist = HBoxContainer.new()
	vbox_dist.add_child(hbox_dist)
	hbox_dist.owner = root

	var btn_p1 = Button.new()
	btn_p1.name = "BtnSimSmallPush"
	btn_p1.text = "60N"
	btn_p1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_dist.add_child(btn_p1)
	btn_p1.owner = root

	var btn_p2 = Button.new()
	btn_p2.name = "BtnSimMedPush"
	btn_p2.text = "160N"
	btn_p2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_dist.add_child(btn_p2)
	btn_p2.owner = root

	var btn_p3 = Button.new()
	btn_p3.name = "BtnSimStrongPush"
	btn_p3.text = "350N (Fall)"
	btn_p3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_dist.add_child(btn_p3)
	btn_p3.owner = root

	# Obstacles Card
	var card_obs = PanelContainer.new()
	card_obs.add_theme_stylebox_override("panel", style_card)
	left_vbox.add_child(card_obs)
	card_obs.owner = root

	var vbox_obs = VBoxContainer.new()
	vbox_obs.add_theme_constant_override("separation", 5)
	card_obs.add_child(vbox_obs)
	vbox_obs.owner = root

	var lbl_obs_hdr = Label.new()
	lbl_obs_hdr.text = "ENVIRONMENT OBSTACLES"
	lbl_obs_hdr.add_theme_font_size_override("font_size", 13)
	lbl_obs_hdr.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vbox_obs.add_child(lbl_obs_hdr)
	lbl_obs_hdr.owner = root

	var hbox_obs1 = HBoxContainer.new()
	vbox_obs.add_child(hbox_obs1)
	hbox_obs1.owner = root

	var btn_ob_c = Button.new()
	btn_ob_c.name = "BtnSimSpawnCube"
	btn_ob_c.text = "+ Cube"
	btn_ob_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_obs1.add_child(btn_ob_c)
	btn_ob_c.owner = root

	var btn_ob_cy = Button.new()
	btn_ob_cy.name = "BtnSimSpawnCyl"
	btn_ob_cy.text = "+ Cylinder"
	btn_ob_cy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_obs1.add_child(btn_ob_cy)
	btn_ob_cy.owner = root

	var hbox_obs2 = HBoxContainer.new()
	vbox_obs.add_child(hbox_obs2)
	hbox_obs2.owner = root

	var btn_ob_b = Button.new()
	btn_ob_b.name = "BtnSimSpawnBarrier"
	btn_ob_b.text = "+ Barrier"
	btn_ob_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_obs2.add_child(btn_ob_b)
	btn_ob_b.owner = root

	var btn_ob_r = Button.new()
	btn_ob_r.name = "BtnSimSpawnRamp"
	btn_ob_r.text = "+ Ramp"
	btn_ob_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_obs2.add_child(btn_ob_r)
	btn_ob_r.owner = root

	var btn_ob_w = Button.new()
	btn_ob_w.name = "BtnSimSpawnWall"
	btn_ob_w.text = "+ Wall"
	vbox_obs.add_child(btn_ob_w)
	btn_ob_w.owner = root

	var btn_ob_clr = Button.new()
	btn_ob_clr.name = "BtnSimClearObs"
	btn_ob_clr.text = "Clear All Obstacles"
	vbox_obs.add_child(btn_ob_clr)
	btn_ob_clr.owner = root

	var chk_av = CheckBox.new()
	chk_av.name = "ChkSimAvoidance"
	chk_av.text = "Reactive Obstacle Avoidance"
	chk_av.button_pressed = true
	vbox_obs.add_child(chk_av)
	chk_av.owner = root

	# Right Panel Toggle Button
	var btn_tog_r = Button.new()
	btn_tog_r.name = "BtnToggleRight"
	btn_tog_r.text = "▶"
	btn_tog_r.set_anchor_and_offset(SIDE_RIGHT, 1, -38)
	btn_tog_r.position.y = 10
	btn_tog_r.custom_minimum_size = Vector2(28, 28)
	tab_sim.add_child(btn_tog_r)
	btn_tog_r.owner = root

	# Right Panel (Joints Inspector)
	var right_p = PanelContainer.new()
	right_p.name = "RightPanel"
	right_p.set_anchor_and_offset(SIDE_RIGHT, 1, -45)
	right_p.set_anchor_and_offset(SIDE_LEFT, 1, -415)
	right_p.set_anchor_and_offset(SIDE_TOP, 0, 10)
	right_p.set_anchor_and_offset(SIDE_BOTTOM, 1, -170)
	right_p.add_theme_stylebox_override("panel", style_panel)
	tab_sim.add_child(right_p)
	right_p.owner = root

	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 6)
	right_p.add_child(right_vbox)
	right_vbox.owner = root

	var lbl_rp_hdr = Label.new()
	lbl_rp_hdr.text = "JOINT CONTROL & INSPECTOR"
	lbl_rp_hdr.add_theme_font_size_override("font_size", 13)
	lbl_rp_hdr.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	right_vbox.add_child(lbl_rp_hdr)
	lbl_rp_hdr.owner = root

	# Category Filter Buttons
	var filter_hbox = HBoxContainer.new()
	right_vbox.add_child(filter_hbox)
	filter_hbox.owner = root

	for cat in ["ALL", "HEAD", "ARMS", "LEGS"]:
		var b_cat = Button.new()
		b_cat.name = "BtnFilter_" + cat
		b_cat.text = cat
		b_cat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		filter_hbox.add_child(b_cat)
		b_cat.owner = root

	var btn_rst_j = Button.new()
	btn_rst_j.name = "BtnResetAllJoints"
	btn_rst_j.text = "Release Manual Overrides"
	right_vbox.add_child(btn_rst_j)
	btn_rst_j.owner = root

	var right_scroll = ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(right_scroll)
	right_scroll.owner = root

	var j_vbox = VBoxContainer.new()
	j_vbox.name = "JointsVBox"
	j_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	j_vbox.add_theme_constant_override("separation", 6)
	right_scroll.add_child(j_vbox)
	j_vbox.owner = root

	# Bottom Panel Toggle Button
	var btn_tog_b = Button.new()
	btn_tog_b.name = "BtnToggleBottom"
	btn_tog_b.text = "▼"
	btn_tog_b.set_anchor_and_offset(SIDE_BOTTOM, 1, -165)
	btn_tog_b.position.x = 10
	btn_tog_b.custom_minimum_size = Vector2(28, 28)
	tab_sim.add_child(btn_tog_b)
	btn_tog_b.owner = root

	# Bottom Panel (Event Log)
	var bottom_p = PanelContainer.new()
	bottom_p.name = "BottomPanel"
	bottom_p.set_anchor_and_offset(SIDE_LEFT, 0, 45)
	bottom_p.set_anchor_and_offset(SIDE_RIGHT, 1, -45)
	bottom_p.set_anchor_and_offset(SIDE_BOTTOM, 1, -10)
	bottom_p.set_anchor_and_offset(SIDE_TOP, 1, -160)
	bottom_p.add_theme_stylebox_override("panel", style_panel)
	tab_sim.add_child(bottom_p)
	bottom_p.owner = root

	var b_vbox = VBoxContainer.new()
	b_vbox.add_theme_constant_override("separation", 4)
	bottom_p.add_child(b_vbox)
	b_vbox.owner = root

	var b_hdr_hbox = HBoxContainer.new()
	b_vbox.add_child(b_hdr_hbox)
	b_hdr_hbox.owner = root

	var lbl_log_title = Label.new()
	lbl_log_title.text = "LIVE SIMULATION & PHYSICS EVENT LOG"
	lbl_log_title.add_theme_font_size_override("font_size", 12)
	lbl_log_title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	b_hdr_hbox.add_child(lbl_log_title)
	lbl_log_title.owner = root

	var b_sp = Control.new()
	b_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_hdr_hbox.add_child(b_sp)
	b_sp.owner = root

	var btn_clr_log = Button.new()
	btn_clr_log.name = "BtnClearLog"
	btn_clr_log.text = "Clear Log"
	b_hdr_hbox.add_child(btn_clr_log)
	btn_clr_log.owner = root

	var item_list = ItemList.new()
	item_list.name = "EventLogList"
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b_vbox.add_child(item_list)
	item_list.owner = root

	# =========================================================================
	# TAB PANEL 1: ROBOT CONTROL
	# =========================================================================
	var tab_ctrl = PanelContainer.new()
	tab_ctrl.name = "TabPanel_Control"
	tab_ctrl.set_anchor_and_offset(SIDE_LEFT, 0, 40)
	tab_ctrl.set_anchor_and_offset(SIDE_RIGHT, 0, 560)
	tab_ctrl.set_anchor_and_offset(SIDE_TOP, 0, 20)
	tab_ctrl.set_anchor_and_offset(SIDE_BOTTOM, 1, -20)
	tab_ctrl.add_theme_stylebox_override("panel", style_panel)
	tab_ctrl.visible = false
	content_area.add_child(tab_ctrl)
	tab_ctrl.owner = root

	var sc_ctrl = ScrollContainer.new()
	sc_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab_ctrl.add_child(sc_ctrl)
	sc_ctrl.owner = root

	var vb_tc = VBoxContainer.new()
	vb_tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb_tc.add_theme_constant_override("separation", 14)
	sc_ctrl.add_child(vb_tc)
	vb_tc.owner = root

	var lbl_tc_title = Label.new()
	lbl_tc_title.text = "MULTI-DIRECTIONAL GAIT & LOCOMOTION"
	lbl_tc_title.add_theme_font_size_override("font_size", 15)
	lbl_tc_title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vb_tc.add_child(lbl_tc_title)
	lbl_tc_title.owner = root

	# D-Pad Container
	var card_dpad = PanelContainer.new()
	card_dpad.add_theme_stylebox_override("panel", style_card)
	vb_tc.add_child(card_dpad)
	card_dpad.owner = root

	var vb_dp = VBoxContainer.new()
	vb_dp.alignment = BoxContainer.ALIGNMENT_CENTER
	vb_dp.add_theme_constant_override("separation", 6)
	card_dpad.add_child(vb_dp)
	vb_dp.owner = root

	var btn_fwd = Button.new()
	btn_fwd.name = "BtnDirForward"
	btn_fwd.text = "▲ FORWARD"
	btn_fwd.custom_minimum_size = Vector2(160, 36)
	btn_fwd.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb_dp.add_child(btn_fwd)
	btn_fwd.owner = root

	var hb_dp_mid = HBoxContainer.new()
	hb_dp_mid.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_dp_mid.add_theme_constant_override("separation", 8)
	vb_dp.add_child(hb_dp_mid)
	hb_dp_mid.owner = root

	var btn_lft = Button.new()
	btn_lft.name = "BtnDirLeft"
	btn_lft.text = "◀ TURN LEFT"
	btn_lft.custom_minimum_size = Vector2(120, 36)
	hb_dp_mid.add_child(btn_lft)
	btn_lft.owner = root

	var btn_stp = Button.new()
	btn_stp.name = "BtnDirStop"
	btn_stp.text = "⏹ STOP"
	btn_stp.custom_minimum_size = Vector2(100, 36)
	hb_dp_mid.add_child(btn_stp)
	btn_stp.owner = root

	var btn_rgt = Button.new()
	btn_rgt.name = "BtnDirRight"
	btn_rgt.text = "TURN RIGHT ▶"
	btn_rgt.custom_minimum_size = Vector2(120, 36)
	hb_dp_mid.add_child(btn_rgt)
	btn_rgt.owner = root

	var btn_bwd = Button.new()
	btn_bwd.name = "BtnDirBackward"
	btn_bwd.text = "▼ BACKWARD"
	btn_bwd.custom_minimum_size = Vector2(160, 36)
	btn_bwd.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb_dp.add_child(btn_bwd)
	btn_bwd.owner = root

	# Gait Parameters Card
	var card_gp = PanelContainer.new()
	card_gp.add_theme_stylebox_override("panel", style_card)
	vb_tc.add_child(card_gp)
	card_gp.owner = root

	var vb_gp = VBoxContainer.new()
	vb_gp.add_theme_constant_override("separation", 8)
	card_gp.add_child(vb_gp)
	vb_gp.owner = root

	var lbl_gp_hdr = Label.new()
	lbl_gp_hdr.text = "GAIT PARAMETERS TUNING"
	lbl_gp_hdr.add_theme_font_size_override("font_size", 13)
	lbl_gp_hdr.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vb_gp.add_child(lbl_gp_hdr)
	lbl_gp_hdr.owner = root

	# Speed slider
	var hb_sp = HBoxContainer.new()
	var l_sp_t = Label.new(); l_sp_t.text = "Walking Speed:"; l_sp_t.custom_minimum_size = Vector2(140, 0)
	var l_sp_v = Label.new(); l_sp_v.name = "LblCtrlSpeedVal"; l_sp_v.text = "0.45 m/s"
	hb_sp.add_child(l_sp_t); hb_sp.add_child(l_sp_v)
	vb_gp.add_child(hb_sp); l_sp_t.owner = root; l_sp_v.owner = root; hb_sp.owner = root

	var s_sp = HSlider.new(); s_sp.name = "SldCtrlSpeed"; s_sp.min_value = 0.15; s_sp.max_value = 1.20; s_sp.step = 0.05; s_sp.value = 0.45
	vb_gp.add_child(s_sp); s_sp.owner = root

	# Step Length slider
	var hb_sl = HBoxContainer.new()
	var l_sl_t = Label.new(); l_sl_t.text = "Step Length Amplitude:"; l_sl_t.custom_minimum_size = Vector2(140, 0)
	var l_sl_v = Label.new(); l_sl_v.name = "LblCtrlStepLenVal"; l_sl_v.text = "0.080 rad"
	hb_sl.add_child(l_sl_t); hb_sl.add_child(l_sl_v)
	vb_gp.add_child(hb_sl); l_sl_t.owner = root; l_sl_v.owner = root; hb_sl.owner = root

	var s_sl = HSlider.new(); s_sl.name = "SldCtrlStepLen"; s_sl.min_value = 0.04; s_sl.max_value = 0.12; s_sl.step = 0.005; s_sl.value = 0.08
	vb_gp.add_child(s_sl); s_sl.owner = root

	# Step Duration slider
	var hb_sd = HBoxContainer.new()
	var l_sd_t = Label.new(); l_sd_t.text = "Step Duration / Period:"; l_sd_t.custom_minimum_size = Vector2(140, 0)
	var l_sd_v = Label.new(); l_sd_v.name = "LblCtrlStepDurVal"; l_sd_v.text = "0.45 s"
	hb_sd.add_child(l_sd_t); hb_sd.add_child(l_sd_v)
	vb_gp.add_child(hb_sd); l_sd_t.owner = root; l_sd_v.owner = root; hb_sd.owner = root

	var s_sd = HSlider.new(); s_sd.name = "SldCtrlStepDur"; s_sd.min_value = 0.30; s_sd.max_value = 0.80; s_sd.step = 0.02; s_sd.value = 0.45
	vb_gp.add_child(s_sd); s_sd.owner = root

	# Odometry Card
	var card_odo = PanelContainer.new()
	card_odo.add_theme_stylebox_override("panel", style_card)
	vb_tc.add_child(card_odo)
	card_odo.owner = root

	var vb_odo = VBoxContainer.new()
	vb_odo.add_theme_constant_override("separation", 4)
	card_odo.add_child(vb_odo)
	vb_odo.owner = root

	var lbl_odo_hdr = Label.new()
	lbl_odo_hdr.text = "LIVE ODOMETRY & GAIT PHASE"
	lbl_odo_hdr.add_theme_font_size_override("font_size", 13)
	lbl_odo_hdr.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vb_odo.add_child(lbl_odo_hdr)
	lbl_odo_hdr.owner = root

	var odo_labels = [
		["LblCtrlDir", "Direction: FORWARD"],
		["LblCtrlSpeed", "Speed: 0.00 m/s"],
		["LblCtrlDist", "Distance: 0.00 m"],
		["LblCtrlSupport", "Support: DOUBLE"]
	]
	for ol in odo_labels:
		var l = Label.new(); l.name = ol[0]; l.text = ol[1]; l.add_theme_font_size_override("font_size", 11)
		vb_odo.add_child(l); l.owner = root

	var prg_gait = ProgressBar.new()
	prg_gait.name = "ProgCtrlGait"
	prg_gait.custom_minimum_size = Vector2(0, 16)
	vb_odo.add_child(prg_gait)
	prg_gait.owner = root

	# =========================================================================
	# TAB PANEL 2: BALANCE MONITORING
	# =========================================================================
	var tab_bal = PanelContainer.new()
	tab_bal.name = "TabPanel_Balance"
	tab_bal.set_anchor_and_offset(SIDE_LEFT, 0, 40)
	tab_bal.set_anchor_and_offset(SIDE_RIGHT, 0, 620)
	tab_bal.set_anchor_and_offset(SIDE_TOP, 0, 20)
	tab_bal.set_anchor_and_offset(SIDE_BOTTOM, 1, -20)
	tab_bal.add_theme_stylebox_override("panel", style_panel)
	tab_bal.visible = false
	content_area.add_child(tab_bal)
	tab_bal.owner = root

	var sc_bal = ScrollContainer.new()
	sc_bal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab_bal.add_child(sc_bal)
	sc_bal.owner = root

	var vb_tb = VBoxContainer.new()
	vb_tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb_tb.add_theme_constant_override("separation", 12)
	sc_bal.add_child(vb_tb)
	vb_tb.owner = root

	var lbl_tb_title = Label.new()
	lbl_tb_title.text = "BALANCE & STABILITY MONITORING"
	lbl_tb_title.add_theme_font_size_override("font_size", 15)
	lbl_tb_title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vb_tb.add_child(lbl_tb_title)
	lbl_tb_title.owner = root

	# Waveform Graph Canvas
	var g_bal = Control.new()
	g_bal.name = "GraphBalance"
	g_bal.set_script(graph_script)
	g_bal.set("graph_title", "Torso Roll & Pitch Posture Angle (°)")
	g_bal.set("series_a_name", "Roll")
	g_bal.set("series_b_name", "Pitch")
	g_bal.set("series_a_color", Color(0.0, 0.9, 1.0))
	g_bal.set("series_b_color", Color(1.0, 0.5, 0.2))
	g_bal.set("y_min", -30.0)
	g_bal.set("y_max", 30.0)
	g_bal.custom_minimum_size = Vector2(480, 130)
	vb_tb.add_child(g_bal)
	g_bal.owner = root

	# Posture & COM Cards
	var card_geom = PanelContainer.new()
	card_geom.add_theme_stylebox_override("panel", style_card)
	vb_tb.add_child(card_geom)
	card_geom.owner = root

	var vb_gm = VBoxContainer.new()
	vb_gm.add_theme_constant_override("separation", 3)
	card_geom.add_child(vb_gm)
	vb_gm.owner = root

	var geom_labels = [
		["LblBalRoll", "Roll: +0.0°"],
		["LblBalPitch", "Pitch: +0.0°"],
		["LblBalYaw", "Yaw: +0.0°"],
		["LblBalCOM", "COM (3D): (0.00, 0.00, 0.85)m"],
		["LblBalCOMProj", "Ground Proj: (0.00, 0.00)m"],
		["LblBalError", "Balance Error: 0.000 m"],
		["LblBalSupportStatus", "Support Polygon: STABLE"],
		["LblBalFootLeft", "Left Foot: GROUNDED"],
		["LblBalFootRight", "Right Foot: GROUNDED"]
	]
	for gl in geom_labels:
		var l = Label.new(); l.name = gl[0]; l.text = gl[1]; l.add_theme_font_size_override("font_size", 11)
		vb_gm.add_child(l); l.owner = root

	# PID Gains Tuning Card
	var card_pid = PanelContainer.new()
	card_pid.add_theme_stylebox_override("panel", style_card)
	vb_tb.add_child(card_pid)
	card_pid.owner = root

	var vb_pid = VBoxContainer.new()
	vb_pid.add_theme_constant_override("separation", 6)
	card_pid.add_child(vb_pid)
	vb_pid.owner = root

	var lbl_pid_hdr = Label.new()
	lbl_pid_hdr.text = "ACTIVE PID BALANCE CONTROLLER TUNING"
	lbl_pid_hdr.add_theme_font_size_override("font_size", 13)
	lbl_pid_hdr.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vb_pid.add_child(lbl_pid_hdr)
	lbl_pid_hdr.owner = root

	# Helper for PID slider rows
	var make_pid_row = func(parent, sld_name, lbl_name, title, def_val, min_v, max_v):
		var hb = HBoxContainer.new()
		var lt = Label.new(); lt.text = title; lt.custom_minimum_size = Vector2(110, 0); lt.add_theme_font_size_override("font_size", 11)
		var lv = Label.new(); lv.name = lbl_name; lv.text = "%.2f" % def_val; lv.custom_minimum_size = Vector2(45, 0); lv.add_theme_font_size_override("font_size", 11)
		var sld = HSlider.new(); sld.name = sld_name; sld.min_value = min_v; sld.max_value = max_v; sld.step = 0.05; sld.value = def_val
		sld.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(lt); hb.add_child(lv); hb.add_child(sld)
		parent.add_child(hb)
		lt.owner = root; lv.owner = root; sld.owner = root; hb.owner = root

	make_pid_row.call(vb_pid, "SldPidPKp", "LblPidPKpVal", "Pitch Kp:", 6.0, 0.0, 15.0)
	make_pid_row.call(vb_pid, "SldPidPKi", "LblPidPKiVal", "Pitch Ki:", 0.5, 0.0, 4.0)
	make_pid_row.call(vb_pid, "SldPidPKd", "LblPidPKdVal", "Pitch Kd:", 0.4, 0.0, 2.0)
	make_pid_row.call(vb_pid, "SldPidRKp", "LblPidRKpVal", "Roll Kp:", 5.0, 0.0, 12.0)
	make_pid_row.call(vb_pid, "SldPidRKi", "LblPidRKiVal", "Roll Ki:", 0.3, 0.0, 3.0)
	make_pid_row.call(vb_pid, "SldPidRKd", "LblPidRKdVal", "Roll Kd:", 0.3, 0.0, 1.5)

	var btn_pid_rst = Button.new()
	btn_pid_rst.name = "BtnPidResetDefaults"
	btn_pid_rst.text = "Reset PID Gains to Defaults"
	vb_pid.add_child(btn_pid_rst)
	btn_pid_rst.owner = root

	# =========================================================================
	# TAB PANEL 3: SENSORS
	# =========================================================================
	var tab_sens = PanelContainer.new()
	tab_sens.name = "TabPanel_Sensors"
	tab_sens.set_anchor_and_offset(SIDE_LEFT, 0, 40)
	tab_sens.set_anchor_and_offset(SIDE_RIGHT, 0, 560)
	tab_sens.set_anchor_and_offset(SIDE_TOP, 0, 20)
	tab_sens.set_anchor_and_offset(SIDE_BOTTOM, 1, -20)
	tab_sens.add_theme_stylebox_override("panel", style_panel)
	tab_sens.visible = false
	content_area.add_child(tab_sens)
	tab_sens.owner = root

	var sc_sens = ScrollContainer.new()
	sc_sens.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab_sens.add_child(sc_sens)
	sc_sens.owner = root

	var vb_ts = VBoxContainer.new()
	vb_ts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb_ts.add_theme_constant_override("separation", 14)
	sc_sens.add_child(vb_ts)
	vb_ts.owner = root

	var lbl_ts_title = Label.new()
	lbl_ts_title.text = "SENSOR ARRAY & OBSTACLE DETECTION"
	lbl_ts_title.add_theme_font_size_override("font_size", 15)
	lbl_ts_title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vb_ts.add_child(lbl_ts_title)
	lbl_ts_title.owner = root

	var card_sb = PanelContainer.new()
	card_sb.add_theme_stylebox_override("panel", style_card)
	vb_ts.add_child(card_sb)
	card_sb.owner = root

	var lbl_sb = Label.new()
	lbl_sb.name = "LblSensStatusBanner"
	lbl_sb.text = "Proximity Status: CLEAR"
	lbl_sb.add_theme_font_size_override("font_size", 14)
	lbl_sb.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
	card_sb.add_child(lbl_sb)
	lbl_sb.owner = root

	var card_sdist = PanelContainer.new()
	card_sdist.add_theme_stylebox_override("panel", style_card)
	vb_ts.add_child(card_sdist)
	card_sdist.owner = root

	var vb_sd = VBoxContainer.new()
	vb_sd.add_theme_constant_override("separation", 4)
	card_sdist.add_child(vb_sd)
	vb_sd.owner = root

	var sens_dist_labels = [
		["LblSensFront", "Front Ray: 3.50m"],
		["LblSensLeft", "Left Ray: 3.50m"],
		["LblSensRight", "Right Ray: 3.50m"],
		["LblSensMin", "Min Clearance: 3.50m"],
		["LblLidarSummary", "16-Ray LiDAR: Active (360° Sector Scan)"]
	]
	for sdl in sens_dist_labels:
		var l = Label.new(); l.name = sdl[0]; l.text = sdl[1]; l.add_theme_font_size_override("font_size", 12)
		vb_sd.add_child(l); l.owner = root

	var card_scfg = PanelContainer.new()
	card_scfg.add_theme_stylebox_override("panel", style_card)
	vb_ts.add_child(card_scfg)
	card_scfg.owner = root

	var vb_scfg = VBoxContainer.new()
	vb_scfg.add_theme_constant_override("separation", 8)
	card_scfg.add_child(vb_scfg)
	vb_scfg.owner = root

	var hb_srg = HBoxContainer.new()
	var l_srg_t = Label.new(); l_srg_t.text = "Max Detection Range:"; l_srg_t.custom_minimum_size = Vector2(150, 0)
	var l_srg_v = Label.new(); l_srg_v.name = "LblSensRangeVal"; l_srg_v.text = "3.5m"
	hb_srg.add_child(l_srg_t); hb_srg.add_child(l_srg_v)
	vb_scfg.add_child(hb_srg); l_srg_t.owner = root; l_srg_v.owner = root; hb_srg.owner = root

	var s_srg = HSlider.new(); s_srg.name = "SldSensRange"; s_srg.min_value = 1.0; s_srg.max_value = 8.0; s_srg.step = 0.5; s_srg.value = 3.5
	vb_scfg.add_child(s_srg); s_srg.owner = root

	var chk_av_m = CheckBox.new()
	chk_av_m.name = "ChkSensAvoid"
	chk_av_m.text = "Autonomous Steering Avoidance Enabled"
	chk_av_m.button_pressed = true
	vb_scfg.add_child(chk_av_m)
	chk_av_m.owner = root

	# =========================================================================
	# TAB PANEL 4: ANALYTICS
	# =========================================================================
	var tab_ana = PanelContainer.new()
	tab_ana.name = "TabPanel_Analytics"
	tab_ana.set_anchor_and_offset(SIDE_LEFT, 0, 40)
	tab_ana.set_anchor_and_offset(SIDE_RIGHT, 0, 600)
	tab_ana.set_anchor_and_offset(SIDE_TOP, 0, 20)
	tab_ana.set_anchor_and_offset(SIDE_BOTTOM, 1, -20)
	tab_ana.add_theme_stylebox_override("panel", style_panel)
	tab_ana.visible = false
	content_area.add_child(tab_ana)
	tab_ana.owner = root

	var sc_ana = ScrollContainer.new()
	sc_ana.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab_ana.add_child(sc_ana)
	sc_ana.owner = root

	var vb_ta = VBoxContainer.new()
	vb_ta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb_ta.add_theme_constant_override("separation", 14)
	sc_ana.add_child(vb_ta)
	vb_ta.owner = root

	var lbl_ta_title = Label.new()
	lbl_ta_title.text = "SIMULATION ANALYTICS & PERFORMANCE"
	lbl_ta_title.add_theme_font_size_override("font_size", 15)
	lbl_ta_title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vb_ta.add_child(lbl_ta_title)
	lbl_ta_title.owner = root

	var g_ana = Control.new()
	g_ana.name = "GraphAnalytics"
	g_ana.set_script(graph_script)
	g_ana.set("graph_title", "Instantaneous Speed (m/s) & Scaled Balance Error")
	g_ana.set("series_a_name", "Speed")
	g_ana.set("series_b_name", "Error*10")
	g_ana.set("series_a_color", Color(0.2, 0.9, 0.4))
	g_ana.set("series_b_color", Color(1.0, 0.3, 0.3))
	g_ana.set("y_min", 0.0)
	g_ana.set("y_max", 2.0)
	g_ana.custom_minimum_size = Vector2(480, 130)
	vb_ta.add_child(g_ana)
	g_ana.owner = root

	var card_kpi = PanelContainer.new()
	card_kpi.add_theme_stylebox_override("panel", style_card)
	vb_ta.add_child(card_kpi)
	card_kpi.owner = root

	var vb_kpi = VBoxContainer.new()
	vb_kpi.add_theme_constant_override("separation", 4)
	card_kpi.add_child(vb_kpi)
	vb_kpi.owner = root

	var ana_labels = [
		["LblAnaDist", "Total Distance: 0.00 m"],
		["LblAnaAvgSpeed", "Instant Speed: 0.00 m/s"],
		["LblAnaMaxTilt", "Max Tilt: 0.0°"],
		["LblAnaFalls", "Falls Sustained: 0"],
		["LblAnaCollisions", "Collisions: 0"],
		["LblAnaStability", "Stability Score: 100.0%"]
	]
	for al in ana_labels:
		var l = Label.new(); l.name = al[0]; l.text = al[1]; l.add_theme_font_size_override("font_size", 12)
		vb_kpi.add_child(l); l.owner = root

	var btn_exp_csv = Button.new()
	btn_exp_csv.name = "BtnExportCsv"
	btn_exp_csv.text = "📥 Export Full Telemetry CSV"
	vb_ta.add_child(btn_exp_csv)
	btn_exp_csv.owner = root

	# =========================================================================
	# TAB PANEL 5: EXPERIMENTS
	# =========================================================================
	var tab_exp = PanelContainer.new()
	tab_exp.name = "TabPanel_Experiments"
	tab_exp.set_anchor_and_offset(SIDE_LEFT, 0, 40)
	tab_exp.set_anchor_and_offset(SIDE_RIGHT, 0, 600)
	tab_exp.set_anchor_and_offset(SIDE_TOP, 0, 20)
	tab_exp.set_anchor_and_offset(SIDE_BOTTOM, 1, -20)
	tab_exp.add_theme_stylebox_override("panel", style_panel)
	tab_exp.visible = false
	content_area.add_child(tab_exp)
	tab_exp.owner = root

	var sc_exp = ScrollContainer.new()
	sc_exp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab_exp.add_child(sc_exp)
	sc_exp.owner = root

	var vb_te = VBoxContainer.new()
	vb_te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb_te.add_theme_constant_override("separation", 12)
	sc_exp.add_child(vb_te)
	vb_te.owner = root

	var lbl_te_title = Label.new()
	lbl_te_title.text = "PREDEFINED ROBOTICS EXPERIMENTS"
	lbl_te_title.add_theme_font_size_override("font_size", 15)
	lbl_te_title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vb_te.add_child(lbl_te_title)
	lbl_te_title.owner = root

	var opt_exp = OptionButton.new()
	opt_exp.name = "OptExpScenario"
	vb_te.add_child(opt_exp)
	opt_exp.owner = root

	var card_ed = PanelContainer.new()
	card_ed.add_theme_stylebox_override("panel", style_card)
	vb_te.add_child(card_ed)
	card_ed.owner = root

	var vb_ed = VBoxContainer.new()
	vb_ed.add_theme_constant_override("separation", 5)
	card_ed.add_child(vb_ed)
	vb_ed.owner = root

	var lbl_et = Label.new()
	lbl_et.name = "LblExpTitle"
	lbl_et.text = "Experiment 1: Basic Walking Dynamics"
	lbl_et.add_theme_font_size_override("font_size", 13)
	lbl_et.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vb_ed.add_child(lbl_et)
	lbl_et.owner = root

	var lbl_ed = Label.new()
	lbl_ed.name = "LblExpDesc"
	lbl_ed.text = "Executes forward locomotion test."
	lbl_ed.add_theme_font_size_override("font_size", 11)
	vb_ed.add_child(lbl_ed)
	lbl_ed.owner = root

	var prg_exp = ProgressBar.new()
	prg_exp.name = "ProgExp"
	prg_exp.custom_minimum_size = Vector2(0, 18)
	vb_ed.add_child(prg_exp)
	prg_exp.owner = root

	var lbl_es = Label.new()
	lbl_es.name = "LblExpStatus"
	lbl_es.text = "Status: NOT_RUN"
	lbl_es.add_theme_font_size_override("font_size", 12)
	vb_ed.add_child(lbl_es)
	lbl_es.owner = root

	# Checklist
	var card_chk = PanelContainer.new()
	card_chk.add_theme_stylebox_override("panel", style_card)
	vb_te.add_child(card_chk)
	card_chk.owner = root

	var vb_chk = VBoxContainer.new()
	vb_chk.add_theme_constant_override("separation", 4)
	card_chk.add_child(vb_chk)
	vb_chk.owner = root

	var lbl_chk_hdr = Label.new()
	lbl_chk_hdr.text = "VERIFICATION CRITERIA CHECKLIST"
	lbl_chk_hdr.add_theme_font_size_override("font_size", 12)
	lbl_chk_hdr.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vb_chk.add_child(lbl_chk_hdr)
	lbl_chk_hdr.owner = root

	var c_boxes = ["ChkExpC1", "ChkExpC2", "ChkExpC3", "ChkExpC4", "ChkExpC5"]
	for cb_name in c_boxes:
		var cb = CheckBox.new(); cb.name = cb_name; cb.text = "Criterion"; cb.disabled = true
		vb_chk.add_child(cb); cb.owner = root

	var hb_ebtns = HBoxContainer.new()
	vb_te.add_child(hb_ebtns)
	hb_ebtns.owner = root

	var btn_es = Button.new(); btn_es.name = "BtnExpStart"; btn_es.text = "▶ Start Experiment"; btn_es.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn_ep = Button.new(); btn_ep.name = "BtnExpStop"; btn_ep.text = "⏹ Stop"; btn_ep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn_er = Button.new(); btn_er.name = "BtnExpReset"; btn_er.text = "↺ Reset"; btn_er.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_ebtns.add_child(btn_es); hb_ebtns.add_child(btn_ep); hb_ebtns.add_child(btn_er)
	btn_es.owner = root; btn_ep.owner = root; btn_er.owner = root

	var btn_eexp = Button.new()
	btn_eexp.name = "BtnExpExportCsv"
	btn_eexp.text = "📥 Export Experiment CSV"
	vb_te.add_child(btn_eexp)
	btn_eexp.owner = root

	# =========================================================================
	# TAB PANEL 6: SETTINGS
	# =========================================================================
	var tab_set = PanelContainer.new()
	tab_set.name = "TabPanel_Settings"
	tab_set.set_anchor_and_offset(SIDE_LEFT, 0, 40)
	tab_set.set_anchor_and_offset(SIDE_RIGHT, 0, 560)
	tab_set.set_anchor_and_offset(SIDE_TOP, 0, 20)
	tab_set.set_anchor_and_offset(SIDE_BOTTOM, 1, -20)
	tab_set.add_theme_stylebox_override("panel", style_panel)
	tab_set.visible = false
	content_area.add_child(tab_set)
	tab_set.owner = root

	var sc_set = ScrollContainer.new()
	sc_set.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab_set.add_child(sc_set)
	sc_set.owner = root

	var vb_tset = VBoxContainer.new()
	vb_tset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb_tset.add_theme_constant_override("separation", 14)
	sc_set.add_child(vb_tset)
	vb_tset.owner = root

	var lbl_tset_title = Label.new()
	lbl_tset_title.text = "PHYSICS ENGINE & SIMULATOR SETTINGS"
	lbl_tset_title.add_theme_font_size_override("font_size", 15)
	lbl_tset_title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vb_tset.add_child(lbl_tset_title)
	lbl_tset_title.owner = root

	# Gravity
	var card_grav = PanelContainer.new()
	card_grav.add_theme_stylebox_override("panel", style_card)
	vb_tset.add_child(card_grav)
	card_grav.owner = root

	var vb_gv = VBoxContainer.new()
	vb_gv.add_theme_constant_override("separation", 6)
	card_grav.add_child(vb_gv)
	vb_gv.owner = root

	var hb_gv = HBoxContainer.new()
	var l_gv_t = Label.new(); l_gv_t.text = "Gravity:"; l_gv_t.custom_minimum_size = Vector2(100, 0)
	var l_gv_v = Label.new(); l_gv_v.name = "LblSetGravityVal"; l_gv_v.text = "-9.81 m/s²"
	hb_gv.add_child(l_gv_t); hb_gv.add_child(l_gv_v)
	vb_gv.add_child(hb_gv); l_gv_t.owner = root; l_gv_v.owner = root; hb_gv.owner = root

	var s_gv = HSlider.new(); s_gv.name = "SldSetGravity"; s_gv.min_value = -20.0; s_gv.max_value = 0.0; s_gv.step = 0.1; s_gv.value = -9.81
	vb_gv.add_child(s_gv); s_gv.owner = root

	var hb_gp = HBoxContainer.new()
	vb_gv.add_child(hb_gp)
	hb_gp.owner = root

	var btn_ge = Button.new(); btn_ge.name = "BtnGravEarth"; btn_ge.text = "Earth (-9.81)"; btn_ge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn_gm = Button.new(); btn_gm.name = "BtnGravMoon"; btn_gm.text = "Moon (-1.62)"; btn_gm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn_gma = Button.new(); btn_gma.name = "BtnGravMars"; btn_gma.text = "Mars (-3.71)"; btn_gma.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn_gz = Button.new(); btn_gz.name = "BtnGravZero"; btn_gz.text = "Zero-G (0.0)"; btn_gz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_gp.add_child(btn_ge); hb_gp.add_child(btn_gm); hb_gp.add_child(btn_gma); hb_gp.add_child(btn_gz)
	btn_ge.owner = root; btn_gm.owner = root; btn_gma.owner = root; btn_gz.owner = root

	# Timestep
	var card_ts = PanelContainer.new()
	card_ts.add_theme_stylebox_override("panel", style_card)
	vb_tset.add_child(card_ts)
	card_ts.owner = root

	var vb_tsl = VBoxContainer.new()
	vb_tsl.add_theme_constant_override("separation", 6)
	card_ts.add_child(vb_tsl)
	vb_tsl.owner = root

	var hb_ts = HBoxContainer.new()
	var l_ts_t = Label.new(); l_ts_t.text = "Physics Step:"; l_ts_t.custom_minimum_size = Vector2(100, 0)
	var l_ts_v = Label.new(); l_ts_v.name = "LblSetTimestepVal"; l_ts_v.text = "60 Hz (0.0167s)"
	hb_ts.add_child(l_ts_t); hb_ts.add_child(l_ts_v)
	vb_tsl.add_child(hb_ts); l_ts_t.owner = root; l_ts_v.owner = root; hb_ts.owner = root

	var s_ts = HSlider.new(); s_ts.name = "SldSetTimestep"; s_ts.min_value = 30.0; s_ts.max_value = 240.0; s_ts.step = 30.0; s_ts.value = 60.0
	vb_tsl.add_child(s_ts); s_ts.owner = root

	# Simulation Speed
	var card_ss = PanelContainer.new()
	card_ss.add_theme_stylebox_override("panel", style_card)
	vb_tset.add_child(card_ss)
	card_ss.owner = root

	var vb_ss = VBoxContainer.new()
	vb_ss.add_theme_constant_override("separation", 6)
	card_ss.add_child(vb_ss)
	vb_ss.owner = root

	var lbl_ss_t = Label.new(); lbl_ss_t.text = "Simulation Time Multiplier:"
	vb_ss.add_child(lbl_ss_t); lbl_ss_t.owner = root

	var opt_ss = OptionButton.new(); opt_ss.name = "OptSetSimSpeed"
	vb_ss.add_child(opt_ss); opt_ss.owner = root

	# Credits Card
	var card_cred = PanelContainer.new()
	card_cred.add_theme_stylebox_override("panel", style_card)
	vb_tset.add_child(card_cred)
	card_cred.owner = root

	var vb_cred = VBoxContainer.new()
	vb_cred.add_theme_constant_override("separation", 4)
	card_cred.add_child(vb_cred)
	vb_cred.owner = root

	var lbl_cr1 = Label.new(); lbl_cr1.text = "VR HUMANOID ROBOT SIMULATOR"; lbl_cr1.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	var lbl_cr2 = Label.new(); lbl_cr2.text = "Engineering End Semester Examination (ESE) Project\nDeveloped by Aryan & Vilas"
	var lbl_cr3 = Label.new(); lbl_cr3.text = "Physics Engine: PyBullet 3.2.7 | 3D Visualization: Godot 4.7.2 | Protocol: TCP JSON"
	lbl_cr2.add_theme_font_size_override("font_size", 11)
	lbl_cr3.add_theme_font_size_override("font_size", 10)
	vb_cred.add_child(lbl_cr1); vb_cred.add_child(lbl_cr2); vb_cred.add_child(lbl_cr3)
	lbl_cr1.owner = root; lbl_cr2.owner = root; lbl_cr3.owner = root

	# Save packed scene
	var packed_scene = PackedScene.new()
	var pack_err = packed_scene.pack(root)
	if pack_err == OK:
		var save_err = ResourceSaver.save(packed_scene, "res://scenes/main.tscn")
		if save_err == OK:
			print("[Builder] Successfully generated and saved res://scenes/main.tscn!")
		else:
			printerr("[Builder] Failed to save scene: ", save_err)
	else:
		printerr("[Builder] Failed to pack scene: ", pack_err)

	quit()
