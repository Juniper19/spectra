extends CharacterBody2D

# Movement settings
@export var speed: float = 200.0
@export var jump_force: float = 400.0
@export var gravity: float = 1000.0

# Color settings
@export var colors: Array[Color] = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW]
var current_color_index: int = 0
var spawn_position: Vector2

# Color selection UI
var selecting_color := false
var selected_index := -1
@onready var color_selector = $"../UI/ColorSelector"

@onready var sprite: AnimatedSprite2D = $Block

func _ready() -> void:
	sprite.modulate = colors[current_color_index]
	update_collision_masks()
	spawn_position = global_position
	color_selector.visible = false
	
	# Force UI to build its colors immediately on load
	color_selector.colors = colors
	color_selector.highlight(current_color_index)


func _physics_process(delta: float) -> void:
	# gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	# only apply player input if not selecting color
	if not selecting_color:
		var direction = Input.get_axis("left", "right")
		velocity.x = direction * speed
		# allow jumping as usual
		if Input.is_action_just_pressed("up") and is_on_floor():
			velocity.y = -jump_force
	else:
		# no new input — but keep momentum (don't zero velocity)
		# optional: apply slight drag if you want subtle slowdown while in slow-mo
		velocity.x = lerp(velocity.x, 0.0, 0.02)

	move_and_slide()

	handle_color_selector()
	check_deathpit()



# ---------------- Color Selector Logic ----------------

func handle_color_selector() -> void:
	# --- open selector (when pressing Space / ui_accept) ---
	if Input.is_action_just_pressed("ui_accept"):
		selecting_color = true
		selected_index = current_color_index
		color_selector.visible = true
		color_selector.colors = colors
		color_selector.set_meta("camera", $Camera2D)
		await get_tree().process_frame
		color_selector.highlight(selected_index)
		Engine.time_scale = 0.2

	# --- while selector is open ---
	if selecting_color:
		# handle color swapping inputs
		if Input.is_action_just_pressed("left"):
			selected_index = (selected_index - 1 + colors.size()) % colors.size()
			color_selector.highlight(selected_index)
			_apply_color(selected_index)

		elif Input.is_action_just_pressed("right"):
			selected_index = (selected_index + 1) % colors.size()
			color_selector.highlight(selected_index)
			_apply_color(selected_index)

	# --- close selector (when releasing Space / ui_accept) ---
	if Input.is_action_just_released("ui_accept"):
		selecting_color = false
		color_selector.visible = false
		Engine.time_scale = 1.0

			
func _apply_color(index: int) -> void:
	current_color_index = index
	sprite.modulate = colors[index]
	update_collision_masks()

func get_index_from_direction(dir: Vector2, total: int) -> int:
	var angle = dir.angle() # radians (-PI to PI)
	if angle < 0:
		angle += TAU
	var slice_angle = TAU / total
	return int(round(angle / slice_angle)) % total

# ---------------- Collision Masks ----------------

func update_collision_masks() -> void:
	set_collision_mask_value(1, true) # white
	set_collision_mask_value(2, false) # red
	set_collision_mask_value(3, false) # blue
	set_collision_mask_value(4, false) # green 
	set_collision_mask_value(5, false) # yellow
	
	set_collision_mask_value(16, true) # deathpit (always active)

	# Enable the current color
	match current_color_index:
		0: # red
			set_collision_mask_value(2, true)
		1: # green
			set_collision_mask_value(4, true)
		2: # blue
			set_collision_mask_value(3, true)
		3: #yellow
			set_collision_mask_value(5, true)

# ---------------- Death Logic ----------------

func check_deathpit() -> void:
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is TileMapLayer and collider.name == "DeathPitLayer":
			respawn()
			
func respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
