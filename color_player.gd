extends CharacterBody2D

# Movement settings
@export var speed: float = 200.0
@export var jump_force: float = 400.0
@export var gravity: float = 1000.0

# Color settings
@export var colors: Array[Color] = [Color.RED, Color.GREEN, Color.BLUE]
var current_color_index: int = 0

@onready var sprite: AnimatedSprite2D = $Block

@onready var spawn_point: Node2D = $"../SpawnPoint"

func _ready() -> void:
	sprite.modulate = colors[current_color_index]
	update_collision_masks()

func _physics_process(delta: float) -> void:
	# Apply gravity
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

	# Death check (after movement)
	if is_in_death_pit():
		respawn()

	# Color cycling
	if Input.is_action_just_pressed("ui_accept"): # space
		cycle_color()

func cycle_color() -> void:
	current_color_index = (current_color_index + 1) % colors.size()
	sprite.modulate = colors[current_color_index]
	update_collision_masks()

func update_collision_masks() -> void:
	set_collision_mask_value(1, true) # white
	set_collision_mask_value(2, false) # red
	set_collision_mask_value(3, false) # blue
	set_collision_mask_value(4, false) # green

	# Enable the current color
	match current_color_index:
		0: # red
			set_collision_mask_value(2, true)
		1: # green
			set_collision_mask_value(4, true)
		2: # blue
			set_collision_mask_value(3, true)
			
# --- Death
func is_in_death_pit() -> bool:
	var death_map: TileMapLayer = get_parent().get_node("DeathPits")  # adjust path
	var cell = death_map.local_to_map(global_position)
	var tile_id = death_map.get_cell_source_id(cell)

	if tile_id != -1:  # means a tile exists at that cell
		print("⚠ Player inside death pit at cell:", cell)
		return true
	return false



func respawn() -> void:
	global_position = spawn_point.global_position
	velocity = Vector2.ZERO
