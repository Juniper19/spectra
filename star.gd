@tool
extends Area2D

@export var star_color: Color
@export var star_name: String = ""  # optional, defaults to node name

func _ready() -> void:
	# Use node name (like "StarRED") 
	if star_name == "":
		star_name = name

	# --- Check if this star was already collected ---
	if get_tree().root.has_meta("collected_stars"):
		var collected: Array = get_tree().root.get_meta("collected_stars")
		if star_name in collected:
			queue_free()
			return

	# --- Set visual color ---
	modulate = star_color

	if not Engine.is_editor_hint():
		connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	# Expect player to have total_colors and unlock_color()
	var player := body
	if not ("total_colors" in player and "unlock_color" in player):
		push_warning("Player missing color methods.")
		return

	var idx := _find_color_index(player.total_colors, star_color)
	if idx == -1:
		push_warning("Star color not found in total_colors.")
		return

	player.unlock_color(idx)

	# --- Mark star as collected globally ---
	var collected_stars: Array = get_tree().root.get_meta("collected_stars") if get_tree().root.has_meta("collected_stars") else []
	if star_name not in collected_stars:
		collected_stars.append(star_name)
		get_tree().root.set_meta("collected_stars", collected_stars)

	queue_free()

func _find_color_index(list: Array[Color], target: Color) -> int:
	for i in range(list.size()):
		if list[i].is_equal_approx(target):
			return i
	return -1
