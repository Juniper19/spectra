extends Control

@export var colors: Array[Color]:
	set(value):
		colors = value
		if is_inside_tree() and value.size() > 0:
			_refresh_colors()
			queue_redraw()

var selected_index: int = -1
var swatch_panels: Array[Panel] = []
var swatch_boxes: Array[StyleBoxFlat] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("ColorSelector ready in tree:", is_inside_tree())
	queue_redraw()
	
func _refresh_colors() -> void:
	if colors.is_empty():
		selected_index = -1
	else:
		selected_index = clamp(selected_index, 0, colors.size() - 1)
	queue_redraw()
	
func _draw() -> void:
	if colors.is_empty():
		return

	var center := size / 2.0
	var radius := 70.0    # pulled in close
	var arrow_length := 45.0
	var arrow_width := 28.0
	var gap := 15.0       # minimal space between player and arrow base

	var angles := [
		deg_to_rad(-90),  # up
		deg_to_rad(0),    # right
		deg_to_rad(90),   # down
		deg_to_rad(180)   # left
	]

	for i in range(colors.size()):
		var angle: float = angles[i % angles.size()]
		var dir := Vector2(cos(angle), sin(angle))

		# Tip near the player
		var tip := center + dir * (radius + arrow_length / 2.0)
		var base_center := center + dir * (radius - gap)

		var perp := dir.rotated(PI / 2.0) * (arrow_width / 2.0)

		var p1 := tip
		var p2 := base_center + perp
		var p3 := base_center - perp

		var c := colors[i]
		if i == selected_index:
			c = c.lightened(0.25)
		else:
			c = c.darkened(0.35)

		draw_colored_polygon([p1, p2, p3], c)

func highlight(index: int) -> void:
	selected_index = clamp(index, 0, colors.size() - 1)
	queue_redraw()

func _process(_delta: float) -> void:
	if not has_meta("camera"):
		return

	var cam: Camera2D = get_meta("camera")
	if cam == null:
		return

	var player := cam.get_parent() as Node2D
	if player:
		# World → Screen using the active canvas transform (includes Camera2D)
		var vp: Viewport = get_viewport()
		var xform: Transform2D = vp.get_canvas_transform()
		var screen_pos: Vector2 = xform * player.global_position

		# Place the bar centered above the player
		position = screen_pos - size / 2.0

func _make_outline_material(outline_color: Color, thickness: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
		shader_type canvas_item;
		uniform vec4 outline_color : source_color;
		uniform float thickness = 2.0;

		void fragment() {
			vec4 col = texture(TEXTURE, UV);
			if (col.a < 0.1) {
				float alpha = 0.0;
				for (float x = -thickness; x <= thickness; x++) {
					for (float y = -thickness; y <= thickness; y++) {
						alpha = max(alpha, texture(TEXTURE, UV + vec2(x, y) / TEXTURE_PIXEL_SIZE.xy).a);
					}
				}
				COLOR = vec4(outline_color.rgb, alpha * outline_color.a);
			} else {
				COLOR = col;
			}
		}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("outline_color", outline_color)
	mat.set_shader_parameter("thickness", thickness)
	return mat

func _adaptive_outline(c: Color) -> Color:
	var brightness = (c.r + c.g + c.b) / 3.0
	if brightness > 0.6:
		# if color is bright (like yellow/green), darken instead of lighten
		return c.darkened(0.4)
	else:
		# if color is dark (like red/blue), lighten
		return c.lightened(0.4)

func animate_open(is_opening: bool) -> void:
	if swatch_panels.is_empty():
		return

	var base_radius := 80.0
	for i in range(swatch_panels.size()):
		var panel := swatch_panels[i]
		var angle := atan2(panel.position.y - size.y / 2.0, panel.position.x - size.x / 2.0)
		var target_radius := base_radius if is_opening else 0.0

		var tween := create_tween().set_ignore_time_scale(true)
		tween.tween_property(
			panel,
			"position",
			size / 2.0 + Vector2(cos(angle), sin(angle)) * target_radius - panel.custom_minimum_size / 2.0,
			0.18
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
