extends AnimatedSprite2D

@export var colors: Array[Color] = [Color.RED, Color.GREEN, Color.BLUE]
var current_color_index: int = 0

func set_color(new_color: Color) -> void:
	self.modulate = new_color

func _ready():
	sprite.modulate = colors[current_color_index]

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"): # "space" by default
		cycle_color()

func cycle_color() -> void:
	# Move to next index, wrapping around
	current_color_index = (current_color_index + 1) % colors.size()
	sprite.modulate = colors[current_color_index]
