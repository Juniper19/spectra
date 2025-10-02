extends Control

var colors: Array[Color] = []
var selected_index: int = -1

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var center = size / 2
	var radius = min(size.x, size.y) / 3
	var slice_angle = TAU / colors.size()  # TAU = 2*PI

	for i in range(colors.size()):
		var angle_from = i * slice_angle - slice_angle/2
		var angle_to = angle_from + slice_angle

		# draw each slice as an arc
		draw_arc(center, radius, angle_from, slice_angle, 32, colors[i], radius)

		# highlight if selected
		if i == selected_index:
			draw_arc(center, radius+8, angle_from, slice_angle, 32, Color.WHITE, 4)

func highlight(index: int) -> void:
	selected_index = index
	queue_redraw()
