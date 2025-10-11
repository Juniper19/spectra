extends Control

@export var clockwise_visual: bool = true

var colors: Array[Color] = []
var selected_index: int = -1

func _ready() -> void:
	# (Optional) ensure the dial still updates while you slow time
	process_mode = Node.PROCESS_MODE_ALWAYS
	queue_redraw()

func _process(_delta: float) -> void:
	# The player’s Camera2D is passed in from the Player:
	#   color_selector.set_meta("camera", $Camera2D)
	var camera: Camera2D = get_meta("camera", null)
	if camera:
		var player := camera.get_parent() as Node2D
		if player:
			# World -> screen using the viewport’s canvas transform
			var canvas_xf: Transform2D = get_viewport().get_canvas_transform()
			var screen_pos: Vector2 = canvas_xf * player.global_position

			# If your Dial’s anchors are centered (all 0.5) and pivot is set to size/2,
			# you can use `position = screen_pos`. Otherwise, center it manually:
			position = screen_pos - size * 0.5

func _draw() -> void:
	if colors.is_empty():
		return

	var center: Vector2 = size / 2.0
	var outer_radius: float = 120.0
	var thickness: float = 12.0
	var slice_angle: float = TAU / float(colors.size())
	var dir: float = -1.0 if clockwise_visual else 1.0

	for i in range(colors.size()):
		var angle_center: float = dir * float(i) * slice_angle
		var angle_from: float = angle_center - (slice_angle * 0.5)
		var angle_to: float = angle_center + (slice_angle * 0.5)

		draw_arc(center, outer_radius, angle_from, angle_to, 48, colors[i], thickness, true)

		if i == selected_index:
			draw_arc(center, outer_radius + 4.0, angle_from, angle_to, 48, Color.WHITE, 4.0, true)

func highlight(index: int) -> void:
	selected_index = index
	queue_redraw()
