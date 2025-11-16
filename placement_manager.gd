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
var current_color: String = "red"
@onready var placed_blocks := $PlacedBlocks

@onready var ghost_block := $GhostBlock


# ------------------------------------------------------
# Get PlacedBlocks dynamically (prevents freed reference)
# ------------------------------------------------------
func get_placed_blocks() -> Node:
	return $PlacedBlocks


# -----------------------------
# Ready
# -----------------------------
func _ready() -> void:
	_load_level_inventory()
	ghost_block.visible = false


# -----------------------------
# Load inventory from LevelConfig
# -----------------------------
func _load_level_inventory() -> void:
	var level := get_tree().current_scene

	if level.has_node("LevelConfig"):
		var config = level.get_node("LevelConfig")
		red_blocks = config.red_blocks
		green_blocks = config.green_blocks
		blue_blocks = config.blue_blocks
	else:
		push_warning("No LevelConfig found.")


# -----------------------------
# Input
# -----------------------------
func _input(event: InputEvent) -> void:
	# toggle build mode
	if event.is_action_pressed("toggle_build_mode"):
		is_build_mode = !is_build_mode
		ghost_block.visible = is_build_mode

		# NEW: tell the player
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.set_build_mode(is_build_mode)

		_set_player_frozen(is_build_mode)
		_set_grid_visible(is_build_mode)
		return

	if not is_build_mode:
		return

	# change color
	if event.is_action_pressed("block_color_red"):
		_set_block_color("red")
	elif event.is_action_pressed("block_color_green"):
		_set_block_color("green")
	elif event.is_action_pressed("block_color_blue"):
		_set_block_color("blue")

	# place block
	if event.is_action_pressed("place_block"):
		_try_place_block()

	# delete block
	if event.is_action_pressed("delete_block"):
		_try_delete_block()


func _set_block_color(color: String) -> void:
	current_color = color

	var sprite := ghost_block.get_node("Sprite2D")

	match color:
		"red": sprite.modulate = Color(1, 0.4, 0.4, 0.4)
		"green": sprite.modulate = Color(0.4, 1, 0.4, 0.4)
		"blue": sprite.modulate = Color(0.4, 0.4, 1, 0.4)


# -----------------------------
# Process
# -----------------------------
func _process(delta: float) -> void:
	if not is_build_mode:
		return

	_update_ghost_position()
	_update_ghost_validity()

func _set_player_frozen(state: bool) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		if "build_frozen" in p:
			p.build_frozen = state

func _set_grid_visible(state: bool) -> void:
	var grid := $GridOverlay   # you'll add a Placeholder Node2D named GridOverlay
	if grid:
		grid.visible = state

func _update_ghost_position() -> void:
	var mouse_pos := get_viewport().get_camera_2d().get_global_mouse_position()

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
		match current_color:
			"red": sprite.modulate = Color(1, 0.4, 0.4, 0.4)
			"green": sprite.modulate = Color(0.4, 1, 0.4, 0.4)
			"blue": sprite.modulate = Color(0.4, 0.4, 1, 0.4)
		x_sprite.visible = false
	else:
		sprite.modulate = Color(1, 0, 0, 0.4)
		x_sprite.visible = true


func _is_valid_position() -> bool:
	var space := get_viewport().get_world_2d().direct_space_state

	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0, ghost_block.global_position - Vector2(8, 8))
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.collision_mask = 2147483647
	params.exclude = [ghost_block]

	var result := space.intersect_shape(params)

	return result.is_empty()


# ------------------------------------------------------
# PLACE BLOCK
# ------------------------------------------------------
func _try_place_block() -> void:
	# check inventory
	match current_color:
		"red": if red_blocks <= 0: return
		"green": if green_blocks <= 0: return
		"blue": if blue_blocks <= 0: return

	# check placement validity
	if not _is_valid_position():
		return

	var block_scene := preload("res://placable_block.tscn")
	var block := block_scene.instantiate()

	block.block_color = current_color
	block.global_position = ghost_block.global_position

	get_placed_blocks().add_child(block)

	# reduce inventory
	match current_color:
		"red": red_blocks -= 1
		"green": green_blocks -= 1
		"blue": blue_blocks -= 1


# ------------------------------------------------------
# DELETE BLOCK (bulletproof)
# ------------------------------------------------------
func _try_delete_block() -> void:
	var block := _get_block_under_mouse()

	if block == null:
		print("NO BLOCK FOUND")
		return

	print("DELETING BLOCK:", block)

	match block.block_color:
		"red": red_blocks += 1
		"green": green_blocks += 1
		"blue": blue_blocks += 1

	block.queue_free()


# ------------------------------------------------------
# Bulletproof raycast to find exact block
# ------------------------------------------------------
func _get_block_under_mouse() -> StaticBody2D:
	var mouse_pos := get_viewport().get_camera_2d().get_global_mouse_position()

	var snapped := Vector2(
		floor(mouse_pos.x / 16.0) * 16.0,
		floor(mouse_pos.y / 16.0) * 16.0
	)

	var space := get_viewport().get_world_2d().direct_space_state

	var params := PhysicsPointQueryParameters2D.new()
	params.position = snapped
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.collision_mask = 2147483647
	params.exclude = [ghost_block]

	var result: Array = space.intersect_point(params)

	for hit: Dictionary in result:
		var collider: Node = hit["collider"]

		# direct block hit
		if collider.get_parent() == placed_blocks:
			return collider as StaticBody2D

		# hit sprite or child of block
		if collider.get_parent() != null and collider.get_parent().get_parent() == placed_blocks:
			return collider.get_parent() as StaticBody2D

	return null
