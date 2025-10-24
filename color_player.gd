extends CharacterBody2D

# ---------------- Movement Settings ----------------
@export var speed: float = 165
@export var jump_force: float = 420
@export var gravity: float = 1200
@export var acceleration: float = 2200
@export var friction: float = 1600
@export var coyote_time: float = 0.05
var coyote_timer: float = 0.0
@export var jump_buffer_time: float = 0.1
var jump_buffer_timer: float = 0.0
@export var jump_cut_multiplier: float = 0.65
@export var apex_gravity_scale: float = 0.7   # lower = floatier apex
@export var apex_threshold: float = 40.0      # smaller = narrower apex zone

# ---------------- Color Settings ----------------
@export var colors: Array[Color] = [Color.RED, Color.GREEN, Color.BLUE]
var current_color_index: int = 0
var spawn_position: Vector2

# ---------------- UI & Sprite References ----------------
var selecting_color := false
var selected_index := -1
@onready var color_selector = $"../UI/ColorSelector"
@onready var sprite: AnimatedSprite2D = $PlayerArt
@onready var shader_mat: ShaderMaterial = $PlayerArt.material

# ---------------- Flow Meter ----------------
var flow_meter: float = 0.0
@export var flow_gain_rate: float = 1.8     # How quickly flow builds per second
@export var flow_decay_rate: float = 10    # How quickly it decays when you stop
@export var max_flow: float = 6           # Cap for flow multiplier
@export var base_speed: float = 165         # Store original base speed separately

@onready var vignette_mat: ShaderMaterial = $FlowVisualizer/Vignette.material

# ---------------- Lifecycle ----------------
func _ready() -> void:
	base_speed = speed

	# Shader color setup
	shader_mat.set_shader_parameter("outline_color", colors[current_color_index])

	update_collision_masks()

	# Check if a door set a spawn point
	var spawn_name = get_tree().root.get_meta("next_spawn_point") if get_tree().root.has_meta("next_spawn_point") else null
	if spawn_name:
		var spawn_node = get_tree().current_scene.get_node_or_null("SpawnPoints/" + str(spawn_name))
		if spawn_node:
			global_position = spawn_node.global_position
			spawn_position = global_position
		get_tree().root.remove_meta("next_spawn_point") # clear it after use
	else:
		spawn_position = global_position

	color_selector.visible = false

	# UI color wheel
	color_selector.colors = colors
	color_selector.highlight(current_color_index)

	# Wait one frame to ensure TileMaps are fully ready before coloring them
	await get_tree().process_frame
	update_tile_outlines()

func _physics_process(delta: float) -> void:
	# ---------------- Jump Buffer ----------------
	if Input.is_action_just_pressed("up"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

	# ---------------- Gravity, Apex Modifier & Variable Jump ----------------
	if not is_on_floor():
		var gravity_force := gravity

		# Apex modifier – lighter gravity near the peak of a jump
		if abs(velocity.y) < apex_threshold:
			gravity_force *= apex_gravity_scale

		# Apply stronger gravity when falling
		if velocity.y > 0:
			gravity_force *= 1.4

		# Apply total gravity force
		velocity.y += gravity_force * delta

		# Variable jump height – cut short if jump is released early
		if velocity.y < 0 and Input.is_action_just_released("up"):
			velocity.y *= jump_cut_multiplier
	else:
		velocity.y = 0

	# ---------------- Coyote Time ----------------
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	# ---------------- Movement ----------------
	if not selecting_color:
		var direction: float = Input.get_axis("left", "right")

		if direction != 0:
			# Detect if changing direction
			if sign(velocity.x) != sign(direction) and abs(velocity.x) > 10.0:
				# Instantly reduce deceleration penalty when reversing
				velocity.x = direction * min(abs(velocity.x), speed)
			
			# Accelerate toward target
			velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
		else:
			# Only apply friction when no input
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)


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

		# Jump logic (buffer + coyote)
		if jump_buffer_timer > 0.0 and (is_on_floor() or coyote_timer > 0.0):
			velocity.y = -jump_force
			coyote_timer = 0.0
			jump_buffer_timer = 0.0

			# preserve a bit of momentum boost based on horizontal speed
			if abs(velocity.x) > speed * 0.8:
				velocity.x *= 1.1

	else:
		# While selecting color, keep momentum
		velocity.x = lerp(velocity.x, 0.0, 0.02)

	# ---------------- Flow Meter Logic ----------------
	var fps := Engine.physics_ticks_per_second
	var real_delta := (1.0 / fps) if fps > 0 else delta

	if is_on_floor():
		var dir := Input.get_axis("left", "right")

		if dir != 0:
			# Player is moving — increase flow
			flow_meter = clampf(flow_meter + flow_gain_rate * real_delta, 0.0, max_flow)
		else:
			# Player is idle — decay flow
			flow_meter = clampf(flow_meter - flow_decay_rate * real_delta, 0.0, max_flow)

	# Update speed based on flow
	var flow_multiplier := 1.0 + (flow_meter / max_flow) * 0.4   # up to +40% speed
	speed = base_speed * flow_multiplier
	print("Flow", flow_meter)
	var vignette_strength: float = flow_meter / max_flow
	vignette_mat.set_shader_parameter("intensity", vignette_strength)
	
	move_and_slide()
	check_deathpit()

# ---------------- Color Selector Logic ----------------
var mouse_selecting := false
var mouse_center: Vector2
var mouse_start_position: Vector2
var drag_threshold: float = 30.0  # how far you must drag before it counts

func _unhandled_input(event: InputEvent) -> void:
	# --- Right mouse button pressed ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and not mouse_selecting:
			mouse_selecting = true
			selecting_color = true
			selected_index = current_color_index

			# Store where drag starts (mouse position in viewport)
			mouse_start_position = event.position

			# Show selector and slow time
			color_selector.visible = true
			color_selector.colors = colors
			color_selector.set_meta("camera", $Camera2D)
			await get_tree().process_frame
			color_selector.highlight(selected_index)
			Engine.time_scale = 0.2

		elif not event.pressed and mouse_selecting:
			# --- Right mouse released ---
			mouse_selecting = false
			selecting_color = false
			color_selector.visible = false
			Engine.time_scale = 1.0

	# --- While dragging ---
	elif event is InputEventMouseMotion and mouse_selecting:
		var delta: Vector2 = event.position - mouse_start_position
		if delta.length() > drag_threshold:
			var angle := atan2(delta.y, delta.x)
			var new_index := _direction_to_index(angle)
			if new_index != selected_index and new_index < colors.size():
				selected_index = new_index
				color_selector.highlight(selected_index)
				_apply_color(selected_index)  # <--- applies instantly

func _direction_to_index(angle: float) -> int:
	var drag_dir := Vector2(cos(angle), sin(angle))
	var dirs := [
		Vector2(0, -1),  # up
		Vector2(1, 0),   # right
		Vector2(0, 1),   # down
		Vector2(-1, 0)   # left
	]

	var best_index := 0
	var best_dot := -INF
	for i in range(dirs.size()):
		var dot := drag_dir.dot(dirs[i])
		if dot > best_dot:
			best_dot = dot
			best_index = i

	return best_index

func _get_screen_position(world_pos: Vector2) -> Vector2:
	var cam: Camera2D = $Camera2D
	if cam == null:
		return world_pos

	# Convert world position to screen position in the same space as event.position
	var viewport := get_viewport()
	var transform: Transform2D = viewport.get_canvas_transform()
	return transform * world_pos

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
			return

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
	var color_names = ["RED", "GREEN", "BLUE", "WHITE"]
	for i in range(color_names.size()):
		var name = color_names[i]
		var node_path = "../Platforms" + name
		if not has_node(node_path):
			continue

		var tm = get_node(node_path)
		if tm == null:
			continue

		# Assign color based on name
		var color: Color
		match name:
			"RED": color = Color.RED
			"GREEN": color = Color.GREEN
			"BLUE": color = Color.BLUE
			"WHITE": color = Color.WHITE

		# Skip white platforms entirely
		if name == "WHITE":
			continue

		# Active layer (matches player color)
		if i == current_color_index:
			# Remove shader and smoothly fade modulate to full color
			tm.material = null
			var tween := create_tween()
			tween.set_ignore_time_scale(true)
			tween.tween_property(tm, "modulate", color, 0.15).set_trans(Tween.TRANS_SINE)
		
		# Inactive layers (outline only)
		else:
			# If missing material, reapply the shader
			if tm.material == null:
				var shader_mat := ShaderMaterial.new()
				shader_mat.shader = preload("res://TileShader.gdshader")
				tm.material = shader_mat
			tm.material.set_shader_parameter("outline_color", color)

			# Smoothly fade back to white (neutral look)
			var tween := create_tween()
			tween.set_ignore_time_scale(true)
			tween.tween_property(tm, "modulate", Color.WHITE, 0.15).set_trans(Tween.TRANS_SINE)


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
