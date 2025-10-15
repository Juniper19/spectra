extends CharacterBody2D

# ---------------- Movement Settings ----------------
@export var speed: float = 200.0
@export var jump_force: float = 400.0
@export var gravity: float = 1000.0

# ---------------- Color Settings ----------------
@export var colors: Array[Color] = [Color.RED, Color.BLUE]
var current_color_index: int = 0
var spawn_position: Vector2

# ---------------- UI & Sprite References ----------------
var selecting_color := false
var selected_index := -1
@onready var color_selector = $"../UI/ColorSelector"
@onready var sprite: AnimatedSprite2D = $PlayerArt
@onready var shader_mat: ShaderMaterial = $PlayerArt.material

# ---------------- Lifecycle ----------------
func _ready() -> void:
	# Initial shader color setup
	shader_mat.set_shader_parameter("outline_color", colors[current_color_index])

	update_collision_masks()
	spawn_position = global_position
	color_selector.visible = false

	# Initialize UI color wheel
	color_selector.colors = colors
	color_selector.highlight(current_color_index)

	# Wait one frame to ensure TileMaps are fully ready before coloring them
	await get_tree().process_frame
	update_tile_outlines()


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	# ---------------- Movement ----------------
	if not selecting_color:
		var direction := Input.get_axis("left", "right")
		velocity.x = direction * speed

		# Flip sprite horizontally
		if direction != 0:
			sprite.flip_h = direction < 0

		# --- Animation Logic ---
		if not is_on_floor():
			if sprite.animation != "jump" or not sprite.is_playing():
				sprite.play("jump")
		else:
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
		# While selecting color, keep momentum
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


# ---------------- Color Handling ----------------
func _apply_color(index: int) -> void:
	current_color_index = index
	update_collision_masks()
	
	# momentum bounce!! IMPORTANT!! without this, you freeze inside tiles
	push_out_of_tiles()

	# update player outline color instantly
	shader_mat.set_shader_parameter("outline_color", colors[index])

	# trigger the bounce effect
	play_color_swap_effect()

	# keep tile outlines fixed
	update_tile_outlines()


func play_color_swap_effect() -> void:
	var tween := create_tween()
	tween.set_ignore_time_scale(true)

	# Simple bounce / squash & stretch
	tween.tween_property(sprite, "scale", Vector2(0.8, 1.2), 0.05).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.05).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.05).set_trans(Tween.TRANS_SINE)

func add_new_color(new_color: Color) -> void:
	# Check if color already exists
	for c in colors:
		if c.is_equal_approx(new_color):
			return # already have it, ignore

	# Add color to the list
	colors.append(new_color)

	# Update UI and visuals
	color_selector.colors = colors
	print("New color unlocked:", new_color)
	print("Total colors:", colors)

	# little bounce effect
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.1)

func push_out_of_tiles() -> void:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape_rid = $CollisionShape2D.shape.get_rid()
	params.collision_mask = get_collision_mask()
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = [self]

	const MAX_PUSH: float = 48.0
	const STEP: float = 2.0
	const BOUNCE: float = 900.0
	const EPS: float = 0.5

	params.transform = Transform2D(0.0, global_position)
	var hits: Array = space_state.intersect_shape(params, 8)
	if hits.is_empty():
		return

	var dirs: Array[Vector2] = [
		Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP,
		Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(),
		Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()
	]

	var best_dir: Vector2 = Vector2.ZERO
	var best_dist: float = INF

	for d in dirs:
		var dist: float = 0.0
		while dist <= MAX_PUSH:
			var test_pos: Vector2 = global_position + d * dist
			params.transform = Transform2D(0.0, test_pos)
			var overlap: Array = space_state.intersect_shape(params, 1)
			if overlap.is_empty():
				if dist < best_dist:
					best_dist = dist
					best_dir = d
				break
			dist += STEP

	if best_dir != Vector2.ZERO and best_dist < INF:
		global_position += best_dir * (best_dist + EPS)

		var depth_ratio: float = clampf((MAX_PUSH - best_dist) / MAX_PUSH, 0.0, 1.0)
		var impulse: Vector2 = best_dir * BOUNCE * depth_ratio
		velocity += impulse


# ---------------- Tile Outline Update ----------------
func update_tile_outlines() -> void:
	for tilemap_name in ["PlatformsRED", "PlatformsGREEN", "PlatformsBLUE", "PlatformsWHITE"]:
		if has_node("../" + tilemap_name):
			var tm = get_node("../" + tilemap_name)
			if tm.material is ShaderMaterial:
				match tilemap_name:
					"PlatformsRED":
						tm.material.set_shader_parameter("outline_color", Color.RED)
					"PlatformsGREEN":
						tm.material.set_shader_parameter("outline_color", Color.GREEN)
					"PlatformsBLUE":
						tm.material.set_shader_parameter("outline_color", Color.BLUE)
					"PlatformsWHITE":
						tm.material.set_shader_parameter("outline_color", Color.WHITE)


# ---------------- Collision Masks ----------------
func update_collision_masks() -> void:
	set_collision_mask_value(1, true)  # white
	set_collision_mask_value(2, false) # red
	set_collision_mask_value(3, false) # blue
	set_collision_mask_value(4, false) # green
	set_collision_mask_value(5, false) # yellow
	set_collision_mask_value(16, true) # deathpit (always active)

	match current_color_index:
		0: set_collision_mask_value(2, true) # red
		1: set_collision_mask_value(3, true) # blue
		2: set_collision_mask_value(4, true) # green
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
