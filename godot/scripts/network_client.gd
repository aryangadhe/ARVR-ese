extends Node
class_name NetworkClient

signal connected_to_server
signal disconnected_from_server
signal telemetry_received(data: Dictionary)

@export var server_host: String = "127.0.0.1"
@export var server_port: int = 9099
@export var reconnect_interval: float = 2.0

var tcp: StreamPeerTCP = StreamPeerTCP.new()
var is_connected_server: bool = false
var reconnect_timer: float = 0.0
var rx_buffer: String = ""

func _ready() -> void:
	connect_to_server()

func connect_to_server() -> void:
	tcp.poll()
	var status = tcp.get_status()
	if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
		var err = tcp.connect_to_host(server_host, server_port)
		if err != OK:
			print("[NetworkClient] Failed to initiate connection: ", err)

func _process(delta: float) -> void:
	tcp.poll()
	var status = tcp.get_status()

	if status == StreamPeerTCP.STATUS_CONNECTED:
		if not is_connected_server:
			is_connected_server = true
			emit_signal("connected_to_server")
			print("[NetworkClient] Connected to Python backend at ", server_host, ":", server_port)
		_read_incoming_data()
	elif status == StreamPeerTCP.STATUS_CONNECTING:
		# In flight connection
		pass
	else:
		if is_connected_server:
			is_connected_server = false
			emit_signal("disconnected_from_server")
			print("[NetworkClient] Disconnected from server.")

		reconnect_timer += delta
		if reconnect_timer >= reconnect_interval:
			reconnect_timer = 0.0
			connect_to_server()

func _read_incoming_data() -> void:
	var bytes_avail = tcp.get_available_bytes()
	if bytes_avail <= 0:
		return

	var raw_data = tcp.get_utf8_string(bytes_avail)
	if raw_data.is_empty():
		return

	rx_buffer += raw_data
	while rx_buffer.contains("\n"):
		var split_idx = rx_buffer.find("\n")
		var line = rx_buffer.substr(0, split_idx).strip_edges()
		rx_buffer = rx_buffer.substr(split_idx + 1)

		if not line.is_empty():
			var json = JSON.new()
			var parse_err = json.parse(line)
			if parse_err == OK:
				var data = json.get_data()
				if typeof(data) == TYPE_DICTIONARY:
					emit_signal("telemetry_received", data)
			else:
				print("[NetworkClient] JSON parse error: ", json.get_error_message())

func send_json(dict: Dictionary) -> void:
	if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var line = JSON.stringify(dict) + "\n"
	tcp.put_utf8_string(line)

func send_command(action: String, extra_params: Dictionary = {}) -> void:
	var payload = {"type": "command", "action": action}
	for k in extra_params:
		payload[k] = extra_params[k]
	send_json(payload)

func send_joint_command(joint_name: String, target_deg: float) -> void:
	send_json({
		"type": "joint_command",
		"joint": joint_name,
		"target_deg": target_deg
	})

func clear_joint(joint_name: String) -> void:
	send_json({
		"type": "clear_joint",
		"joint": joint_name
	})

func clear_all_joints() -> void:
	send_json({"type": "clear_all_joints"})

func send_push(magnitude: float, direction: String = "forward", duration: float = 0.15) -> void:
	send_json({
		"type": "push",
		"magnitude": magnitude,
		"direction": direction,
		"duration": duration
	})

func send_fall_test(level: String) -> void:
	send_json({
		"type": "fall_test",
		"level": level
	})

func spawn_obstacle(obs_type: String, pos: Array, size: Array = []) -> void:
	send_json({
		"type": "spawn_obstacle",
		"obstacle_type": obs_type,
		"position": pos,
		"size": size
	})

func clear_obstacles() -> void:
	send_json({"type": "clear_obstacles"})

func set_pid(gains: Dictionary) -> void:
	var payload = {"type": "set_pid"}
	for k in gains:
		payload[k] = gains[k]
	send_json(payload)

func set_speed(speed: float) -> void:
	send_json({
		"type": "command",
		"action": "walk",
		"speed": speed
	})

func set_simulation_speed(mult: float) -> void:
	send_json({
		"type": "set_simulation_speed",
		"speed_multiplier": mult
	})

func toggle_avoidance(enabled: bool) -> void:
	send_json({
		"type": "toggle_avoidance",
		"enabled": enabled
	})
