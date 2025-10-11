extends Control

@export var colors: Array[Color]:
	set(value):
		colors = value
		if is_inside_tree() and value.size() > 0:
			_refresh_colors()

var selected_index: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("ColorSelector ready in tree:", is_inside_tree())
	queue_redraw()
	
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0, 0, 0.4))
	
func _refresh_colors() -> void:
	# Clear old ColorRects (in case colors changed)
	for child in $"HBoxContainer".get_children():
		child.queue_free()

	# Create one ColorRect per color
	for i in range(colors.size()):
		var rect = ColorRect.new()
		rect.color = colors[i]
		rect.custom_minimum_size = Vector2(64, 64)
		rect.modulate = colors[i]
		rect.name = "Color_%d" % i
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$"HBoxContainer".add_child(rect)

	# Initialize highlight state
	if selected_index < 0:
		selected_index = 0
	highlight(selected_index)
	
	print(colors)

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

	var hbox := $"HBoxContainer"
	var child_count := hbox.get_child_count()
	for i in range(child_count):
		var rect = hbox.get_child(i) as ColorRect
		if i < colors.size():
			if i == selected_index:
				rect.scale = Vector2(1.3, 1.3)
				rect.modulate = colors[i].lightened(0.1)
				rect.material = _make_outline_material(Color.WHITE, 2.0)
			else:
				rect.scale = Vector2.ONE
				rect.modulate = colors[i].darkened(0.2)
				rect.material = null
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
