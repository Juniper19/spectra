@tool
extends Area2D

@export var star_color: Color
@export var star_name: String = ""

func _ready() -> void:
	if star_name == "":
		star_name = name

	if not get_tree().root.has_meta("collected_stars"):
		get_tree().root.set_meta("collected_stars", [])

	var collected: Array = get_tree().root.get_meta("collected_stars")
	if star_name in collected:
		queue_free()
		return

	modulate = star_color

	if not Engine.is_editor_hint():
		connect("body_entered", Callable(self, "_on_body_entered"))

		# Glow pulse via shader — preserves color, bloom amplifies the bright peaks
		var spr := get_node_or_null("AnimatedSprite2D")
		if spr:
			var gm := ShaderMaterial.new()
			gm.shader = preload("res://Color Management/EtherealGlow.gdshader")
			gm.set_shader_parameter("glow_amount", 0.5)
			gm.set_shader_parameter("pulse_speed", randf_range(1.6, 2.8))
			spr.material = gm

		# Random float bob so nearby stars don't sync up
		var start_y := position.y
		var bob_height := randf_range(3.5, 7.0)
		var bob_speed := randf_range(0.9, 1.9)
		var bob := create_tween().set_loops()
		bob.tween_property(self, "position:y", start_y - bob_height, bob_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(self, "position:y", start_y, bob_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	var player := body
	var idx := _find_color_index(player.total_colors, star_color)
	if idx == -1:
		return

	player.unlock_color(idx)

	var collected_stars: Array = get_tree().root.get_meta("collected_stars")
	if star_name not in collected_stars:
		collected_stars.append(star_name)
		get_tree().root.set_meta("collected_stars", collected_stars)

	disconnect("body_entered", Callable(self, "_on_body_entered"))
	_play_collect_flash()

func _play_collect_flash() -> void:
	# Spike to super-bright (bloom turns this into a glow burst), then fade — no scaling
	var flash := create_tween().set_ignore_time_scale(true)
	flash.tween_property(self, "modulate", Color(star_color.r * 5.0, star_color.g * 5.0, star_color.b * 5.0, 1.0), 0.05)
	flash.tween_property(self, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	flash.tween_callback(queue_free)

func _find_color_index(list: Array[Color], target: Color) -> int:
	for i in range(list.size()):
		if list[i].is_equal_approx(target):
			return i
	return -1
