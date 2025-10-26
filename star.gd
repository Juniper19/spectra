@tool
extends Area2D

# --- Each star can have its own color set in the inspector ---
@export var star_color: Color = Color.GREEN:
	set(value):
		star_color = value
		if Engine.is_editor_hint():
			modulate = value

# --- Ready lifecycle ---
func _ready() -> void:
	modulate = star_color
	if not Engine.is_editor_hint():
		connect("body_entered", Callable(self, "_on_body_entered"))

# --- Collision logic ---
func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	var player := body
	if not ("total_colors" in player and "unlock_color" in player):
		push_warning("Player is missing total_colors or unlock_color().")
		return

	var idx := _find_color_index(player.total_colors, star_color)
	if idx == -1:
		push_warning("Star color not found in player's total_colors.")
		return

	player.unlock_color(idx)
	queue_free()  # remove after collection

# --- Utility: find color index in player's total_colors ---
func _find_color_index(list: Array[Color], target: Color) -> int:
	for i in range(list.size()):
		if list[i].is_equal_approx(target):
			return i
	return -1
