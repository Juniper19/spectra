extends StaticBody2D

@export var block_color: String = "red"

func _ready() -> void:
	add_to_group("placeable_block")
	_apply_color()
	_set_collision_layer()


func _apply_color() -> void:
	var sprite := $Sprite2D

	match block_color:
		"red":
			sprite.modulate = Color(1, 0.4, 0.4, 1)
		"green":
			sprite.modulate = Color(0.4, 1, 0.4, 1)
		"blue":
			sprite.modulate = Color(0.4, 0.4, 1, 1)


func _set_collision_layer() -> void:
	# Clear ALL layers first so we don't accidentally stay on layer 1
	for i in range(1, 33):
		set_collision_layer_value(i, false)

	# Now enable only the layer for this color
	match block_color:
		"red":
			set_collision_layer_value(2, true)
		"green":
			set_collision_layer_value(4, true)
		"blue":
			set_collision_layer_value(3, true)
