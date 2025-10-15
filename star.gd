@tool
extends Area2D

@export var star_color: Color = Color.GREEN:
	set(value):
		star_color = value
		if Engine.is_editor_hint():
			modulate = value

func _ready() -> void:
	modulate = star_color
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.add_new_color(star_color)
		queue_free() # remove the star once collected
