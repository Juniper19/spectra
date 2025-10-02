extends CharacterBody2D

# Movement settings
@export var speed: float = 200.0
@export var jump_force: float = 400.0
@export var gravity: float = 1000.0

# Color settings
@export var colors: Array[Color] = [Color.RED, Color.GREEN, Color.BLUE]
var current_color_index: int = 0
var spawn_position: Vector2


@onready var sprite: AnimatedSprite2D = $Block

func _ready() -> void:
	sprite.modulate = colors[current_color_index]
	update_collision_masks()
	
	spawn_position = global_position

func _physics_process(delta: float) -> void:
	# gravity yuh
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	# Horizontal movement
	var direction = Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * speed

	# Jump
	if Input.is_action_just_pressed("ui_up") and is_on_floor():
		velocity.y = -jump_force

	# Apply movement
	move_and_slide()

	# Color cycling
	if Input.is_action_just_pressed("ui_accept"): # space
		cycle_color()
		
	# check for deathpit overlap
	check_deathpit()

func cycle_color() -> void:
	current_color_index = (current_color_index + 1) % colors.size()
	sprite.modulate = colors[current_color_index]
	update_collision_masks()

func update_collision_masks() -> void:
	set_collision_mask_value(1, true) # white
	set_collision_mask_value(2, false) # red
	set_collision_mask_value(3, false) # blue
	set_collision_mask_value(4, false) # green
	
	set_collision_mask_value(16, true) # deathpit (always active)

	# Enable the current color
	match current_color_index:
		0: # red
			set_collision_mask_value(2, true)
		1: # green
			set_collision_mask_value(4, true)
		2: # blue
			set_collision_mask_value(3, true)

#------------------------Death logic-------------------------------------------
func check_deathpit() -> void:
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is TileMapLayer and collider.name == "DeathPitLayer":
			respawn()
			
func respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
