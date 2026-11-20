extends Control
class_name LiveGraph

@export var graph_title: String = "Telemetry Metric"
@export var series_a_name: String = "Channel A"
@export var series_b_name: String = "Channel B"
@export var series_a_color: Color = Color(0.0, 0.85, 1.0)
@export var series_b_color: Color = Color(1.0, 0.45, 0.2)
@export var y_min: float = -45.0
@export var y_max: float = 45.0
@export var max_points: int = 120

var data_a: Array[float] = []
var data_b: Array[float] = []

func _ready() -> void:
	custom_minimum_size = Vector2(280, 140)

func add_sample(val_a: float, val_b: float = 0.0) -> void:
	data_a.append(val_a)
	if data_a.size() > max_points:
		data_a.pop_front()

	data_b.append(val_b)
	if data_b.size() > max_points:
		data_b.pop_front()

	queue_redraw()

func clear() -> void:
	data_a.clear()
	data_b.clear()
	queue_redraw()

func _draw() -> void:
	var w = size.x
	var h = size.y
	if w <= 10 or h <= 10:
		return

	# Background dark canvas
	draw_rect(Rect2(0, 0, w, h), Color(0.06, 0.08, 0.12, 0.95))
	draw_rect(Rect2(0, 0, w, h), Color(0.18, 0.24, 0.32), false, 1.0)

	# Grid lines
	var num_h_lines = 4
	for i in range(num_h_lines + 1):
		var y = i * (h / num_h_lines)
		draw_line(Vector2(0, y), Vector2(w, y), Color(0.15, 0.20, 0.28, 0.6), 1.0)

	# Zero axis
	if y_min < 0 and y_max > 0:
		var zero_norm = (0.0 - y_min) / (y_max - y_min)
		var zero_y = h - (zero_norm * h)
		draw_line(Vector2(0, zero_y), Vector2(w, zero_y), Color(0.35, 0.45, 0.55, 0.8), 1.5)

	# Draw Series A
	if data_a.size() >= 2:
		var pts_a: PackedVector2Array = []
		var count = data_a.size()
		var step_x = w / float(max_points - 1)
		var start_x = (max_points - count) * step_x

		for i in range(count):
			var norm = clamp((data_a[i] - y_min) / (y_max - y_min), 0.0, 1.0)
			var pt_y = h - (norm * h)
			var pt_x = start_x + (i * step_x)
			pts_a.append(Vector2(pt_x, pt_y))
		draw_polyline(pts_a, series_a_color, 2.0, true)

	# Draw Series B (if used)
	if data_b.size() >= 2 and series_b_name != "":
		var pts_b: PackedVector2Array = []
		var count_b = data_b.size()
		var step_x = w / float(max_points - 1)
		var start_x = (max_points - count_b) * step_x

		for i in range(count_b):
			var norm = clamp((data_b[i] - y_min) / (y_max - y_min), 0.0, 1.0)
			var pt_y = h - (norm * h)
			var pt_x = start_x + (i * step_x)
			pts_b.append(Vector2(pt_x, pt_y))
		draw_polyline(pts_b, series_b_color, 2.0, true)

	# Header text
	var font = ThemeDB.fallback_font
	var font_size = 11
	draw_string(font, Vector2(8, 14), graph_title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.7, 0.85, 1.0))

	# Legend and current value
	var cur_a = data_a[-1] if data_a.size() > 0 else 0.0
	var text_a = "%s: %+.1f" % [series_a_name, cur_a]
	draw_string(font, Vector2(w - 180, 14), text_a, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, series_a_color)

	if series_b_name != "":
		var cur_b = data_b[-1] if data_b.size() > 0 else 0.0
		var text_b = "%s: %+.1f" % [series_b_name, cur_b]
		draw_string(font, Vector2(w - 95, 14), text_b, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, series_b_color)
