@tool
extends SceneTree

func _init() -> void:
	print("[Builder] Generating main.tscn for VR Humanoid Robot Simulator...")
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

	root.set_script(main_script)

	# Load materials
	var mat_torso = load("res://materials/torso.tres")
	var mat_limbs = load("res://materials/limbs.tres")
	var mat_joints = load("res://materials/joints.tres")
	var mat_visor = load("res://materials/visor.tres")
	var mat_floor = load("res://materials/floor.tres")

	# 1. WorldEnvironment
	var env_node = WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.08, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.30, 0.38)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.15
	env_node.environment = env
	root.add_child(env_node)
	env_node.owner = root

	# 2. DirectionalLight3D
	var dir_light = DirectionalLight3D.new()
	dir_light.name = "DirectionalLight3D"
	dir_light.position = Vector3(4.0, 8.0, 4.0)
	dir_light.rotation_degrees = Vector3(-45, 40, 0)
	dir_light.shadow_enabled = true
	dir_light.light_energy = 1.1
	dir_light.light_color = Color(0.96, 0.98, 1.0)
	root.add_child(dir_light)
	dir_light.owner = root

	# 3. OmniLight3D (overhead lab spotlight)
	var omni_light = OmniLight3D.new()
	omni_light.name = "LabOverheadLight"
	omni_light.position = Vector3(0.0, 4.5, 0.0)
	omni_light.light_color = Color(0.3, 0.8, 1.0)
	omni_light.light_energy = 1.6
	omni_light.omni_range = 16.0
	root.add_child(omni_light)
	omni_light.owner = root

	# 4. Laboratory Environment
	var lab_env = Node3D.new()
	lab_env.name = "LaboratoryEnvironment"
	root.add_child(lab_env)
	lab_env.owner = root

	# Floor
	var floor_mesh = MeshInstance3D.new()
	floor_mesh.name = "FloorGrid"
	var p_mesh = PlaneMesh.new()
	p_mesh.size = Vector2(30, 30)
	floor_mesh.mesh = p_mesh
	floor_mesh.material_override = mat_floor
	lab_env.add_child(floor_mesh)
	floor_mesh.owner = root

	# Circular Testing Platform in center
	var platform = MeshInstance3D.new()
	platform.name = "CenterPlatform"
	var cyl_plat = CylinderMesh.new()
	cyl_plat.top_radius = 3.5
	cyl_plat.bottom_radius = 3.5
	cyl_plat.height = 0.03
	platform.mesh = cyl_plat
	platform.position = Vector3(0, 0.015, 0)
	platform.material_override = mat_torso
	lab_env.add_child(platform)
	platform.owner = root

	# Decorative boundary walls
	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.12, 0.15, 0.20)
	wall_mat.roughness = 0.7

	var wall_north = MeshInstance3D.new()
	wall_north.name = "WallNorth"
	var b_mesh = BoxMesh.new()
	b_mesh.size = Vector3(30, 6, 0.5)
	wall_north.mesh = b_mesh
	wall_north.position = Vector3(0, 3, -15)
	wall_north.material_override = wall_mat
	lab_env.add_child(wall_north)
	wall_north.owner = root

	# 5. CameraController
	var cam_ctrl = Node3D.new()
	cam_ctrl.name = "CameraController"
	cam_ctrl.set_script(cam_script)
	root.add_child(cam_ctrl)
	cam_ctrl.owner = root

	var cam3d = Camera3D.new()
	cam3d.name = "Camera3D"
	cam3d.current = true
	cam3d.fov = 60.0
	cam3d.position = Vector3(0, 1.2, 3.2)
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

	# Helper to create link mesh instances
	# 1. Torso
	var torso_node = MeshInstance3D.new()
	torso_node.name = "torso"
	var torso_mesh = BoxMesh.new()
	torso_mesh.size = Vector3(0.22, 0.40, 0.26)
	torso_node.mesh = torso_mesh
	torso_node.material_override = mat_torso
	links_container.add_child(torso_node)
	torso_node.owner = root

	# 2. Head with Visor
	var head_node = Node3D.new()
	head_node.name = "head"
	links_container.add_child(head_node)
	head_node.owner = root

	var head_mesh_inst = MeshInstance3D.new()
	head_mesh_inst.name = "HeadMesh"
	var head_mesh = SphereMesh.new()
	head_mesh.radius = 0.10
	head_mesh.height = 0.20
	head_mesh_inst.mesh = head_mesh
	head_mesh_inst.material_override = mat_limbs
	head_mesh_inst.position = Vector3(0, 0.08, 0)
	head_node.add_child(head_mesh_inst)
	head_mesh_inst.owner = root

	var visor_mesh_inst = MeshInstance3D.new()
	visor_mesh_inst.name = "VisorMesh"
	var visor_mesh = BoxMesh.new()
	visor_mesh.size = Vector3(0.12, 0.04, 0.03)
	visor_mesh_inst.mesh = visor_mesh
	visor_mesh_inst.material_override = mat_visor
	visor_mesh_inst.position = Vector3(0, 0.09, -0.09)
	head_node.add_child(visor_mesh_inst)
	visor_mesh_inst.owner = root

	# Limb definitions: [name, radius, height, material]
	var limb_defs = [
		["left_upper_arm", 0.04, 0.22, mat_limbs],
		["left_forearm", 0.035, 0.20, mat_limbs],
		["right_upper_arm", 0.04, 0.22, mat_limbs],
		["right_forearm", 0.035, 0.20, mat_limbs],
		["left_thigh", 0.05, 0.30, mat_limbs],
		["left_shin", 0.045, 0.28, mat_limbs],
		["right_thigh", 0.05, 0.30, mat_limbs],
		["right_shin", 0.045, 0.28, mat_limbs],
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
		links_container.add_child(l_node)
		l_node.owner = root

	# Feet (BoxMeshes)
	for foot_name in ["left_foot", "right_foot"]:
		var f_node = MeshInstance3D.new()
		f_node.name = foot_name
		var f_mesh = BoxMesh.new()
		f_mesh.size = Vector3(0.14, 0.04, 0.24)
		f_node.mesh = f_mesh
		f_node.material_override = mat_torso
		links_container.add_child(f_node)
		f_node.owner = root

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

	# Assign inspector properties
	ui_node.set("network_client", net_node)
	ui_node.set("camera_controller", cam_ctrl)
	xr_origin.set("xr_origin", xr_origin)
	xr_origin.set("desktop_camera", cam3d)

	# --- Header Bar ---
	var header = PanelContainer.new()
	header.name = "Header"
	header.set_anchor_and_offset(SIDE_LEFT, 0, 0)
	header.set_anchor_and_offset(SIDE_RIGHT, 1, 0)
	header.set_anchor_and_offset(SIDE_TOP, 0, 0)
	header.set_anchor_and_offset(SIDE_BOTTOM, 0, 48)

	var h_mat = StyleBoxFlat.new()
	h_mat.bg_color = Color(0.08, 0.10, 0.14, 0.95)
	h_mat.border_color = Color(0.0, 0.7, 0.9, 0.5)
	h_mat.border_width_bottom = 2
	header.add_theme_stylebox_override("panel", h_mat)
	ui_node.add_child(header)
	header.owner = root

	var header_hbox = HBoxContainer.new()
	header_hbox.name = "HBox"
	header_hbox.add_theme_constant_override("separation", 20)
	header.add_child(header_hbox)
	header_hbox.owner = root

	var lbl_title = Label.new()
	lbl_title.text = "  VR HUMANOID ROBOT SIMULATOR"
	lbl_title.add_theme_font_size_override("font_size", 16)
	lbl_title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	header_hbox.add_child(lbl_title)
	lbl_title.owner = root

	var lbl_conn = Label.new()
	lbl_conn.name = "LblConnection"
	lbl_conn.text = "○ CONNECTING TO SIMULATION..."
	lbl_conn.add_theme_font_size_override("font_size", 13)
	lbl_conn.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
	header_hbox.add_child(lbl_conn)
	lbl_conn.owner = root

	var lbl_xr_text = Label.new()
	lbl_xr_text.name = "LblXR"
	lbl_xr_text.text = "XR: Desktop Mode (Ready)"
	lbl_xr_text.add_theme_font_size_override("font_size", 13)
	lbl_xr_text.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	header_hbox.add_child(lbl_xr_text)
	lbl_xr_text.owner = root

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)
	spacer.owner = root

	var btn_res_cam = Button.new()
	btn_res_cam.name = "BtnResetCam"
	btn_res_cam.text = " Reset Camera "
	header_hbox.add_child(btn_res_cam)
	btn_res_cam.owner = root

	# --- Left Panel ---
	var left_panel = PanelContainer.new()
	left_panel.name = "LeftPanel"
	left_panel.set_anchor_and_offset(SIDE_LEFT, 0, 15)
	left_panel.set_anchor_and_offset(SIDE_TOP, 0, 60)
	left_panel.set_anchor_and_offset(SIDE_RIGHT, 0, 360)
	left_panel.set_anchor_and_offset(SIDE_BOTTOM, 1, -15)

	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.09, 0.11, 0.16, 0.88)
	p_style.border_color = Color(0.15, 0.25, 0.35)
	p_style.set_border_width_all(1)
	p_style.set_corner_radius_all(6)
	left_panel.add_theme_stylebox_override("panel", p_style)
	ui_node.add_child(left_panel)
	left_panel.owner = root

	var left_scroll = ScrollContainer.new()
	left_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_panel.add_child(left_scroll)
	left_scroll.owner = root

	var left_vbox = VBoxContainer.new()
	left_vbox.name = "VBox"
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 14)
	left_scroll.add_child(left_vbox)
	left_vbox.owner = root

	# Status Card
	var status_card = VBoxContainer.new()
	status_card.name = "StatusCard"
	left_vbox.add_child(status_card)
	status_card.owner = root

	var lbl_sc_title = Label.new()
	lbl_sc_title.text = "ROBOT STATUS DASHBOARD"
	lbl_sc_title.add_theme_font_size_override("font_size", 14)
	lbl_sc_title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	status_card.add_child(lbl_sc_title)
	lbl_sc_title.owner = root

	var grid = VBoxContainer.new()
	grid.name = "Grid"
	grid.add_theme_constant_override("separation", 4)
	status_card.add_child(grid)
	grid.owner = root

	var labels_to_add = [
		["LblState", "State: STANDING"],
		["LblBalance", "Balance: STABLE"],
		["LblFallCount", "Fall Count: 0"],
		["LblRPY", "R: +0.0° | P: +0.0° | Y: +0.0°"],
		["LblPos", "Pos: (0.00, 0.00, 0.85)m"],
		["LblWalkPhase", "Gait: STAND / IDLE"],
		["LblSensors", "Sensors: F: 3.50m | L: 3.50m | R: 3.50m"],
		["LblAvoidance", "Avoidance: CLEAR"],
	]
	for l_pair in labels_to_add:
		var l = Label.new()
		l.name = l_pair[0]
		l.text = l_pair[1]
		l.add_theme_font_size_override("font_size", 12)
		grid.add_child(l)
		l.owner = root

	# Controls Card
	var ctrl_card = VBoxContainer.new()
	ctrl_card.name = "ControlsCard"
	ctrl_card.add_theme_constant_override("separation", 6)
	left_vbox.add_child(ctrl_card)
	ctrl_card.owner = root

	var lbl_cc_title = Label.new()
	lbl_cc_title.text = "ROBOT CONTROL"
	lbl_cc_title.add_theme_font_size_override("font_size", 14)
	lbl_cc_title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	ctrl_card.add_child(lbl_cc_title)
	lbl_cc_title.owner = root

	var btn_walk = Button.new()
	btn_walk.name = "BtnWalk"
	btn_walk.text = "▶ START WALKING"
	ctrl_card.add_child(btn_walk)
	btn_walk.owner = root

	var btn_stop = Button.new()
	btn_stop.name = "BtnStop"
	btn_stop.text = "⏹ STOP WALKING"
	ctrl_card.add_child(btn_stop)
	btn_stop.owner = root

	var btn_stand = Button.new()
	btn_stand.name = "BtnStand"
	btn_stand.text = "⚖ RETURN TO STAND"
	ctrl_card.add_child(btn_stand)
	btn_stand.owner = root

	var btn_reset = Button.new()
	btn_reset.name = "BtnReset"
	btn_reset.text = "↺ RESET SIMULATION"
	ctrl_card.add_child(btn_reset)
	btn_reset.owner = root

	# Disturbance Card
	var dist_card = VBoxContainer.new()
	dist_card.name = "DisturbanceCard"
	dist_card.add_theme_constant_override("separation", 6)
	left_vbox.add_child(dist_card)
	dist_card.owner = root

	var lbl_dist_title = Label.new()
	lbl_dist_title.text = "EXTERNAL DISTURBANCE"
	lbl_dist_title.add_theme_font_size_override("font_size", 14)
	lbl_dist_title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	dist_card.add_child(lbl_dist_title)
	lbl_dist_title.owner = root

	var hbox_push = HBoxContainer.new()
	hbox_push.name = "HBoxPush"
	hbox_push.add_theme_constant_override("separation", 6)
	dist_card.add_child(hbox_push)
	hbox_push.owner = root

	var btn_p1 = Button.new()
	btn_p1.name = "BtnSmallPush"
	btn_p1.text = "Small (60N)"
	btn_p1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_push.add_child(btn_p1)
	btn_p1.owner = root

	var btn_p2 = Button.new()
	btn_p2.name = "BtnMedPush"
	btn_p2.text = "Med (160N)"
	btn_p2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_push.add_child(btn_p2)
	btn_p2.owner = root

	var btn_p3 = Button.new()
	btn_p3.name = "BtnStrongPush"
	btn_p3.text = "Fall (350N)"
	btn_p3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_push.add_child(btn_p3)
	btn_p3.owner = root

	# Obstacles Card
	var obs_card = VBoxContainer.new()
	obs_card.name = "ObstaclesCard"
	obs_card.add_theme_constant_override("separation", 6)
	left_vbox.add_child(obs_card)
	obs_card.owner = root

	var lbl_obs_title = Label.new()
	lbl_obs_title.text = "ENVIRONMENT OBSTACLES"
	lbl_obs_title.add_theme_font_size_override("font_size", 14)
	lbl_obs_title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	obs_card.add_child(lbl_obs_title)
	lbl_obs_title.owner = root

	var hbox_obs = HBoxContainer.new()
	hbox_obs.name = "HBoxObs"
	hbox_obs.add_theme_constant_override("separation", 6)
	obs_card.add_child(hbox_obs)
	hbox_obs.owner = root

	var btn_sc = Button.new()
	btn_sc.name = "BtnSpawnCube"
	btn_sc.text = "+ Cube"
	btn_sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_obs.add_child(btn_sc)
	btn_sc.owner = root

	var btn_scy = Button.new()
	btn_scy.name = "BtnSpawnCyl"
	btn_scy.text = "+ Cylinder"
	btn_scy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_obs.add_child(btn_scy)
	btn_scy.owner = root

	var btn_sw = Button.new()
	btn_sw.name = "BtnSpawnWall"
	btn_sw.text = "+ Wall"
	btn_sw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_obs.add_child(btn_sw)
	btn_sw.owner = root

	var btn_clear_o = Button.new()
	btn_clear_o.name = "BtnClearObs"
	btn_clear_o.text = "Clear All Obstacles"
	obs_card.add_child(btn_clear_o)
	btn_clear_o.owner = root

	var chk_av = CheckBox.new()
	chk_av.name = "ChkAvoidance"
	chk_av.text = "Reactive Obstacle Avoidance"
	chk_av.button_pressed = true
	obs_card.add_child(chk_av)
	chk_av.owner = root

	# --- Right Panel ---
	var right_panel = PanelContainer.new()
	right_panel.name = "RightPanel"
	right_panel.set_anchor_and_offset(SIDE_RIGHT, 1, -15)
	right_panel.set_anchor_and_offset(SIDE_LEFT, 1, -380)
	right_panel.set_anchor_and_offset(SIDE_TOP, 0, 60)
	right_panel.set_anchor_and_offset(SIDE_BOTTOM, 1, -15)
	right_panel.add_theme_stylebox_override("panel", p_style)
	ui_node.add_child(right_panel)
	right_panel.owner = root

	var tab_container = TabContainer.new()
	tab_container.name = "TabContainer"
	tab_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	right_panel.add_child(tab_container)
	tab_container.owner = root

	# Tab 1: Joint Control
	var tab_joints = VBoxContainer.new()
	tab_joints.name = "Joints"
	tab_joints.add_theme_constant_override("separation", 6)
	tab_container.add_child(tab_joints)
	tab_joints.owner = root

	var btn_clr_j = Button.new()
	btn_clr_j.name = "BtnResetAllJoints"
	btn_clr_j.text = "Release Manual Joint Overrides"
	tab_joints.add_child(btn_clr_j)
	btn_clr_j.owner = root

	var scroll_j = ScrollContainer.new()
	scroll_j.name = "Scroll"
	scroll_j.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_joints.add_child(scroll_j)
	scroll_j.owner = root

	var vbox_j = VBoxContainer.new()
	vbox_j.name = "JointsVBox"
	vbox_j.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_j.add_theme_constant_override("separation", 8)
	scroll_j.add_child(vbox_j)
	vbox_j.owner = root

	# Tab 2: Simulation Tuning
	var tab_tuning = VBoxContainer.new()
	tab_tuning.name = "Tuning"
	tab_tuning.add_theme_constant_override("separation", 10)
	tab_container.add_child(tab_tuning)
	tab_tuning.owner = root

	var vbox_t = VBoxContainer.new()
	vbox_t.name = "VBox"
	tab_tuning.add_child(vbox_t)
	vbox_t.owner = root

	var lbl_sp_title = Label.new()
	lbl_sp_title.text = "Gait Frequency / Walking Speed"
	vbox_t.add_child(lbl_sp_title)
	lbl_sp_title.owner = root

	var sld_speed = HSlider.new()
	sld_speed.name = "SldWalkSpeed"
	sld_speed.min_value = 0.2
	sld_speed.max_value = 1.5
	sld_speed.step = 0.05
	sld_speed.value = 0.5
	vbox_t.add_child(sld_speed)
	sld_speed.owner = root

	# Pack and save main.tscn
	var packed_scene = PackedScene.new()
	var pack_err = packed_scene.pack(root)
	if pack_err == OK:
		var save_err = ResourceSaver.save(packed_scene, "res://scenes/main.tscn")
		if save_err == OK:
			print("[Builder] Successfully saved res://scenes/main.tscn!")
		else:
			printerr("[Builder] Failed to save scene: ", save_err)
	else:
		printerr("[Builder] Failed to pack scene: ", pack_err)

	quit()
