@tool
extends Area2D

@export var color_index: int = 0
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
	modulate = get_tree().current_scene.get_node("MyPlayer").total_colors[color_index]

	if not Engine.is_editor_hint():
		connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	var player := body
	player.unlock_color(color_index)

	# Mark collected
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
