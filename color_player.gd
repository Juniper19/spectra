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

	# ---------------- Movement ----------------
	if not selecting_color:
		var direction := Input.get_axis("left", "right")
		velocity.x = direction * speed

		# Flip sprite depending on direction
		if direction != 0:
			sprite.flip_h = direction < 0

		# --- Animation Logic ---
		if direction != 0:
			if sprite.animation != "walk" or not sprite.is_playing():
				sprite.play("walk")
		else:
			if sprite.animation != "idle" or not sprite.is_playing():
				sprite.play("idle")

		# Jump
		if Input.is_action_just_pressed("up") and is_on_floor():
			velocity.y = -jump_force

	else:
		# While color selector open, slow slightly but keep momentum
		velocity.x = lerp(velocity.x, 0.0, 0.02)

	move_and_slide()

	handle_color_selector()
	check_deathpit()


# ---------------- Color Selector Logic ----------------

func handle_color_selector() -> void:
	if Input.is_action_just_pressed("ui_accept"):
		selecting_color = true
		selected_index = current_color_index
		color_selector.visible = true
		color_selector.colors = colors
		color_selector.set_meta("camera", $Camera2D)
		await get_tree().process_frame
		color_selector.highlight(selected_index)
		Engine.time_scale = 0.2

	if selecting_color:
		if Input.is_action_just_pressed("left"):
			selected_index = (selected_index - 1 + colors.size()) % colors.size()
			color_selector.highlight(selected_index)
			_apply_color(selected_index)
		elif Input.is_action_just_pressed("right"):
			selected_index = (selected_index + 1) % colors.size()
			color_selector.highlight(selected_index)
			_apply_color(selected_index)

	if Input.is_action_just_released("ui_accept"):
		selecting_color = false
		color_selector.visible = false
		Engine.time_scale = 1.0


func _apply_color(index: int) -> void:
	current_color_index = index
	sprite.modulate = colors[index]
	update_collision_masks()
	play_color_swap_effect(colors[index])
	
func play_color_swap_effect(new_color: Color) -> void:
	var tween := create_tween()
	tween.set_ignore_time_scale(true) 

	# quick squash & stretch
	tween.tween_property(sprite, "scale", Vector2(0.8, 1.2), 0.05).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.05).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.05).set_trans(Tween.TRANS_SINE)

	# apply new color midway through
	await get_tree().create_timer(0.075, false, true).timeout  # ignores time scale
	sprite.modulate = new_color


# ---------------- Collision Masks ----------------

func update_collision_masks() -> void:
	set_collision_mask_value(1, true) # white
	set_collision_mask_value(2, false) # red
	set_collision_mask_value(3, false) # blue
	set_collision_mask_value(4, false) # green
	set_collision_mask_value(5, false) # yellow
	set_collision_mask_value(16, true) # deathpit (always active)

	match current_color_index:
		0: set_collision_mask_value(2, true) # red
		1: set_collision_mask_value(4, true) # green
		2: set_collision_mask_value(3, true) # blue
		3: set_collision_mask_value(5, true) # yellow


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
