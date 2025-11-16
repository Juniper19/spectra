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
	if event.is_action_pressed("toggle_build_mode"):   # you will bind this to Q
		is_build_mode = !is_build_mode
		ghost_block.visible = is_build_mode

func _process(delta: float) -> void:
	if not is_build_mode:
		return

	_update_ghost_position()
	
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
