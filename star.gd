@tool
extends Area2D

@export var star_color: Color = Color.YELLOW:
	set(value):
		star_color = value
		if Engine.is_editor_hint():
			modulate = value

func _ready() -> void:
	modulate = star_color
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	# Expect the player script to expose total_colors: Array[Color] and unlock_color(index: int)
	var player := body
	if not ( "total_colors" in player and "unlock_color" in player ):
		push_warning("Player is missing total_colors or unlock_color().")
		return

	var idx: int = _find_color_index(player.total_colors, star_color)
	if idx == -1:
		push_warning("Star color not found in player's total_colors.")
		return

	player.unlock_color(idx)
	queue_free()

func _find_color_index(list: Array[Color], target: Color) -> int:
	# Prefer approximate compare to avoid floating precision surprises.
	for i in list.size():
		if list[i].is_equal_approx(target):
			return i
	return -1
