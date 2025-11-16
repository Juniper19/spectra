extends Node

# -----------------------------
# Inventory (loaded per-level)
# -----------------------------
var red_blocks: int = 0
var green_blocks: int = 0
var blue_blocks: int = 0

# -----------------------------
# Internal state
# -----------------------------
var is_build_mode: bool = false
var current_color: String = "red"   # for now
@onready var ghost_block := $GhostBlock
@onready var placed_blocks := $PlacedBlocks

func _ready() -> void:
	_load_level_inventory()
	ghost_block.visible = false


# -----------------------------
# Load block inventory from LevelConfig
# -----------------------------
func _load_level_inventory() -> void:
	var level := get_tree().current_scene
	if level.has_node("LevelConfig"):
		var config = level.get_node("LevelConfig")
		red_blocks = config.red_blocks
		green_blocks = config.green_blocks
		blue_blocks = config.blue_blocks
	else:
		push_warning("No LevelConfig node found in this level.")

# -----------------------------
# Toggle build mode
# -----------------------------
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_build_mode"):
		is_build_mode = !is_build_mode
		ghost_block.visible = is_build_mode

	if not is_build_mode:
		return

	# Color switching
	if event.is_action_pressed("block_color_red"):
		_set_block_color("red")
	elif event.is_action_pressed("block_color_green"):
		_set_block_color("green")
	elif event.is_action_pressed("block_color_blue"):
		_set_block_color("blue")
		
	if is_build_mode and event.is_action_pressed("place_block"):
		_try_place_block()

		
func _set_block_color(color: String) -> void:
	current_color = color

	var ghost_sprite := ghost_block.get_node("Sprite2D")

	match color:
		"red":
			ghost_sprite.modulate = Color(1, 0.4, 0.4, 0.4)  # faint red
		"green":
			ghost_sprite.modulate = Color(0.4, 1, 0.4, 0.4)
		"blue":
			ghost_sprite.modulate = Color(0.4, 0.4, 1, 0.4)

func _process(delta: float) -> void:
	if not is_build_mode:
		return

	_update_ghost_position()
	_update_ghost_validity()
	
func _update_ghost_position() -> void:
	# Get the mouse position in world coordinates
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	mouse_pos = get_viewport().get_camera_2d().get_global_mouse_position()

	# Snap to 16x16 grid
	var snapped := Vector2(
		floor(mouse_pos.x / 16.0) * 16.0,
		floor(mouse_pos.y / 16.0) * 16.0
	)

	ghost_block.global_position = snapped

func _update_ghost_validity() -> void:
	var valid := _is_valid_position()

	var sprite := ghost_block.get_node("Sprite2D")
	var x_sprite := ghost_block.get_node("XSprite")

	if valid:
		# restore ghost color based on selected block color
		match current_color:
			"red":
				sprite.modulate = Color(1, 0.4, 0.4, 0.4)
			"green":
				sprite.modulate = Color(0.4, 1, 0.4, 0.4)
			"blue":
				sprite.modulate = Color(0.4, 0.4, 1, 0.4)

		x_sprite.visible = false

	else:
		# invalid = ghost turns red + X icon
		sprite.modulate = Color(1, 0, 0, 0.4)
		x_sprite.visible = true
		
func _is_valid_position() -> bool:
	var space := get_viewport().get_world_2d().direct_space_state

	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0, ghost_block.global_position - Vector2(8, 8))
	params.collide_with_areas = true
	params.collide_with_bodies = true
	params.collision_mask = 2147483647
	params.exclude = [ghost_block]        # << IMPORTANT FIX

	var result: Array = space.intersect_shape(params)

	return result.is_empty()

func _try_place_block() -> void:
	print("TRY PLACE BLOCK TRIGGERED")
	print("Inventory:", red_blocks, green_blocks, blue_blocks)
	print("Valid position?:", _is_valid_position())
	# Check inventory
	match current_color:
		"red":
			if red_blocks <= 0: return
		"green":
			if green_blocks <= 0: return
		"blue":
			if blue_blocks <= 0: return

	# Check placement validity
	if not _is_valid_position():
		return

	# Instantiate the block
	var block_scene := preload("res://placable_block.tscn")
	var block := block_scene.instantiate()

	# Set color
	block.block_color = current_color

	# Position it
	block.global_position = ghost_block.global_position

	# Add it to the PlacedBlocks container
	placed_blocks.add_child(block)

	# Decrease inventory
	match current_color:
		"red": red_blocks -= 1
		"green": green_blocks -= 1
		"blue": blue_blocks -= 1

	print("Placed", current_color, "block. Remaining:", red_blocks, green_blocks, blue_blocks)
