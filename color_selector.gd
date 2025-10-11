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
	
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0, 0, 0.4))
	
func _refresh_colors() -> void:
	# Clear arrays & children
	swatch_panels.clear()
	swatch_boxes.clear()

	var hbox := $"HBoxContainer"
	for child in hbox.get_children():
		child.queue_free()

	# Build a panel per color using StyleBoxFlat
	for i in range(colors.size()):
		var panel := Panel.new()
		panel.name = "Color_%d" % i
		panel.custom_minimum_size = Vector2(64, 64)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var sb := StyleBoxFlat.new()
		sb.bg_color = colors[i]
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8

		# per-side border widths (4.4)
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0, 0, 0, 0) # invisible by default

		panel.add_theme_stylebox_override("panel", sb)
		hbox.add_child(panel)

		swatch_panels.append(panel)
		swatch_boxes.append(sb)

	# Initialize highlight state
	if selected_index < 0:
		selected_index = 0
	highlight(selected_index)

func _process(_delta: float) -> void:
	var cam: Camera2D = get_meta("camera", null)
	if cam:
		var player := cam.get_parent() as Node2D
		if player:
			# World → Screen using the active canvas transform (includes Camera2D)
			var vp: Viewport = get_viewport()
			var xform: Transform2D = vp.get_canvas_transform()
			var screen_pos: Vector2 = xform * player.global_position

			# Place the bar centered above the player
			position = screen_pos - Vector2(size.x / 2.0, size.y + 80.0)

func highlight(index: int) -> void:
	if colors.is_empty():
		return

	selected_index = clamp(index, 0, colors.size() - 1)

	# If we somehow got here before refresh finished, bail gracefully
	if swatch_panels.size() != colors.size():
		return

	for i in range(swatch_panels.size()):
		var panel := swatch_panels[i]
		var sb := swatch_boxes[i]

		if i == selected_index:
			panel.scale = Vector2(1.25, 1.25)
			sb.bg_color = colors[i].lightened(0.10)

			sb.border_width_left = 4
			sb.border_width_right = 4
			sb.border_width_top = 4
			sb.border_width_bottom = 4
			sb.border_color = _adaptive_outline(colors[i])
		else:
			panel.scale = Vector2.ONE
			sb.bg_color = colors[i].darkened(0.20)

			sb.border_width_left = 2
			sb.border_width_right = 2
			sb.border_width_top = 2
			sb.border_width_bottom = 2
			sb.border_color = Color(0, 0, 0, 0)

		# Re-apply override to ensure changes take effect
		panel.add_theme_stylebox_override("panel", sb)

	queue_redraw()

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
