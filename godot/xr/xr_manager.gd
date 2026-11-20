extends Node
class_name XRManager

signal xr_mode_changed(is_active: bool, message: String)

@export var xr_origin: Node3D
@export var desktop_camera: Camera3D

var is_xr_active: bool = false
var xr_interface: XRInterface = null

func _ready() -> void:
	check_and_init_xr()

func check_and_init_xr() -> void:
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		print("[XRManager] OpenXR interface is already initialized.")
		_enable_xr()
	elif xr_interface:
		print("[XRManager] OpenXR interface found. Attempting initialization...")
		if xr_interface.initialize():
			_enable_xr()
		else:
			_fallback_desktop("OpenXR headset not detected or runtime not running.")
	else:
		_fallback_desktop("OpenXR interface not found on system. Using Desktop Mode.")

func _enable_xr() -> void:
	get_viewport().use_xr = true
	is_xr_active = true
	if desktop_camera:
		desktop_camera.current = false
	if xr_origin:
		xr_origin.visible = true
	emit_signal("xr_mode_changed", true, "OpenXR Mode Active")
	print("[XRManager] VR Mode activated successfully via OpenXR.")

func _fallback_desktop(reason: String) -> void:
	get_viewport().use_xr = false
	is_xr_active = false
	if desktop_camera:
		desktop_camera.current = true
	if xr_origin:
		xr_origin.visible = false
	emit_signal("xr_mode_changed", false, "Desktop Mode: " + reason)
	print("[XRManager] " + reason)
