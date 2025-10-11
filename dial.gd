extends Control

@export var clockwise_visual: bool = true  # flip visual order if needed

var colors: Array[Color] = []
var selected_index: int = -1

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	if colors.is_empty():
		return

	var center: Vector2 = size / 2.0
	var radius: float = min(size.x, size.y) / 3.0
	var slice_angle: float = TAU / float(colors.size())

	var dir: float
	if clockwise_visual:
		dir = -1.0
	else:
		dir = 1.0

	for i in range(colors.size()):
		var angle_center: float = dir * float(i) * slice_angle
		var angle_from: float = angle_center - (slice_angle * 0.5)
		var angle_to: float = angle_center + (slice_angle * 0.5)

		# base ring segment
		draw_arc(center, radius, angle_from, angle_to, 48, colors[i], 12.0, true)

		# highlight ring on selected slice
		if i == selected_index:
			draw_arc(center, radius + 8.0, angle_from, angle_to, 48, Color.WHITE, 4.0, true)

func highlight(index: int) -> void:
	selected_index = index
	queue_redraw()
