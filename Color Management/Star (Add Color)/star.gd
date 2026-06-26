@tool
extends Area2D

@export var star_color: Color
@export var star_name: String = ""

func _ready() -> void:
	# Ensure the name is consistent
	if star_name == "":
		star_name = name

	# --- Ensure collected_stars array always exists globally ---
	if not get_tree().root.has_meta("collected_stars"):
		get_tree().root.set_meta("collected_stars", [])

	var collected: Array = get_tree().root.get_meta("collected_stars")

	# --- If star was already collected, remove it ---
	if star_name in collected:
		queue_free()
		return

	# --- Set visual color ---
	modulate = star_color

	if not Engine.is_editor_hint():
		connect("body_entered", Callable(self, "_on_body_entered"))

		var spr := get_node_or_null("AnimatedSprite2D")
		if spr:
			var gm := ShaderMaterial.new()
			gm.shader = preload("res://Color Management/EtherealGlow.gdshader")
			spr.material = gm

		var start_y := position.y
		var bob := create_tween().set_loops()
		bob.tween_property(self, "position:y", start_y - 6.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(self, "position:y", start_y, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	var player := body

	var idx := _find_color_index(player.total_colors, star_color)
	if idx == -1:
		return

	player.unlock_color(idx)

	# --- Mark star as collected ---
	var collected_stars: Array = get_tree().root.get_meta("collected_stars")
	if star_name not in collected_stars:
		collected_stars.append(star_name)
		get_tree().root.set_meta("collected_stars", collected_stars)

	queue_free()

func _find_color_index(list: Array[Color], target: Color) -> int:
	for i in range(list.size()):
		if list[i].is_equal_approx(target):
			return i
	return -1
