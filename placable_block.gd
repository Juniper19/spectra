extends Area2D

@export var block_color: String = "red"

func _ready() -> void:
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
	# Clear all color layers (2=red, 3=blue, 4=green)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, false)
	set_collision_layer_value(4, false)

	# Activate only the correct one
	match block_color:
		"red":
			set_collision_layer_value(2, true)
		"green":
			set_collision_layer_value(4, true)
		"blue":
			set_collision_layer_value(3, true)
