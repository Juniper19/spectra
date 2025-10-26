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

var spawn_position: Vector2
# ---------------- Color Settings ----------------
@export var total_colors: Array[Color] = [
	Color.RED,
	Color.GREEN,
	Color.BLUE,
	Color.YELLOW
]

var unlocked_colors: Array[int] = [1]  #STARTING COLORS based on total color array above
var current_color_index: int = 0

var current_color: Color:
	get:
		return total_colors[unlocked_colors[current_color_index]]

# ---------------- UI & Sprite References ----------------
var selecting_color := false
var selected_index := -1
@onready var color_selector = $"../UI/ColorSelector"
@onready var sprite: AnimatedSprite2D = $PlayerArt
@onready var shader_mat: ShaderMaterial = $PlayerArt.material

# ---------------- Flow Meter ----------------
var flow_meter: float = 0.0
@export var flow_gain_rate: float = 1     # How quickly flow builds per second
@export var flow_decay_rate: float = 10.0   # How quickly it decays when you stop
@export var max_flow: float = 6.0           # Cap for flow multiplier
@export var base_speed: float = 165.0       # Store original base speed separately
@export var flow_idle_grace: float = 0.3    # Seconds before decay starts

# ---------------- Flow Start Delay ----------------
@export var flow_start_delay: float = 2.0   # seconds before flow starts building
var flow_timer: float = 0.0
var flow_enabled: bool = false

var flow_idle_timer: float = 0.0            # Tracks idle time before decay
@onready var vignette_mat: ShaderMaterial = $FlowVisualizer/Vignette.material

# ---------------- Lifecycle ----------------
func _ready() -> void:
	# GET RID OF THIS ONCE COLORS ARE GLOBAL! THIS IS SO UNLOCKED COLORS SYNCH ACROSS SCENES.. 
	if get_tree().root.has_meta("unlocked_colors"):
		unlocked_colors = get_tree().root.get_meta("unlocked_colors")
	else:
		get_tree().root.set_meta("unlocked_colors", unlocked_colors)

	# Prevent crashes if somehow loading without any colors or an invalid index
	if unlocked_colors.is_empty():
		unlocked_colors.append(0)
		current_color_index = 0
	else:
		current_color_index = clamp(current_color_index, 0, unlocked_colors.size() - 1)

	base_speed = speed

	shader_mat.set_shader_parameter("outline_color", current_color)

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
	color_selector.colors = _get_unlocked_color_list()
	color_selector.highlight(current_color_index)

	# Wait one frame to ensure TileMaps are fully ready before coloring them
	await get_tree().process_frame
	update_tile_outlines()

	# Flow start delay setup
	flow_timer = 0.0
	flow_enabled = false


func _physics_process(delta: float) -> void:
	# ---------------- Flow Start Delay ----------------
	if not flow_enabled:
		flow_timer += delta
		if flow_timer >= flow_start_delay:
			flow_enabled = true

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
	if flow_enabled:
		var fps := Engine.physics_ticks_per_second
		var real_delta: float = (1.0 / fps) if fps > 0 else delta

		if is_on_floor():
			var dir: float = Input.get_axis("left", "right")
			var touching_wall: bool = false

			# Detect if player is colliding with a wall in the direction they're pressing
			for i in range(get_slide_collision_count()):
				var collision := get_slide_collision(i)
				if collision.get_normal().x != 0.0:  # horizontal wall
					if sign(collision.get_normal().x) == -sign(dir): 
						touching_wall = true
						break

			var moving: bool = abs(velocity.x) > 5.0 and not touching_wall

			if dir != 0 and moving:
				# Actively moving, not blocked
				flow_idle_timer = 0.0
				flow_meter = clampf(flow_meter + flow_gain_rate * real_delta, 0.0, max_flow)
			else:
				# Idle or pushing into wall
				flow_idle_timer += real_delta
				if flow_idle_timer > flow_idle_grace:
					flow_meter = clampf(flow_meter - flow_decay_rate * real_delta, 0.0, max_flow)

	# if flow hits 0, start a new delay timer before it can rise again
	if flow_enabled and flow_meter <= 0.0:
		flow_enabled = false
		flow_timer = 0.0

	# ---------------- Update speed & vignette ----------------
	var flow_multiplier: float = 1.0 + (flow_meter / max_flow) * 0.7
	speed = base_speed * flow_multiplier

	# Target vignette intensity based on flow
	var target_intensity: float = flow_meter / max_flow
	var current_intensity: float = vignette_mat.get_shader_parameter("intensity")
	var smoothed_intensity: float = lerp(current_intensity, target_intensity, 5.0 * delta)
	vignette_mat.set_shader_parameter("intensity", smoothed_intensity)

	# Smoothly fade vignette color to match player color
	var current_vignette_color: Color = vignette_mat.get_shader_parameter("color")
	var target_color: Color = total_colors[unlocked_colors[current_color_index]]
	var smoothed_color: Color = current_vignette_color.lerp(target_color, 5.0 * delta)
	vignette_mat.set_shader_parameter("color", smoothed_color)
	
	move_and_slide()
	check_deathpit()

# ---------------- Color Selector Logic ----------------
var mouse_selecting := false
var mouse_center: Vector2
var mouse_start_position: Vector2
var drag_threshold: float = 30.0  # how far you must drag before it counts

func _unhandled_input(event: InputEvent) -> void:
	# --- Right Mouse Button Pressed (enter selection) ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and not mouse_selecting:
			if unlocked_colors.size() <= 1:
				return

			mouse_selecting = true
			selecting_color = true
			selected_index = current_color_index
			# Show selector and slow time
			color_selector.visible = true
			color_selector.colors = _get_unlocked_color_list()
			color_selector.set_meta("camera", $Camera2D)
			await get_tree().process_frame
			color_selector.highlight(selected_index)
			Engine.time_scale = 0.2


		# --- Right Mouse Button Released (exit selection) ---
		elif not event.pressed and mouse_selecting:
			mouse_selecting = false
			selecting_color = false
			color_selector.visible = false
			Engine.time_scale = 1.0

	# --- Mouse Movement (hover around selector) ---
	elif event is InputEventMouseMotion and mouse_selecting:
		# Get the color selector's center in viewport coordinates
		var selector_center: Vector2 = color_selector.get_global_transform_with_canvas().origin + color_selector.size / 2.0

		# Calculate direction of mouse relative to the selector's center
		var delta: Vector2 = event.position - selector_center
		if delta.length() > 20.0: # small dead zone in the center
			var angle: float = atan2(delta.y, delta.x)
			var new_index: int = _direction_to_index(angle)

			if new_index != selected_index and new_index < unlocked_colors.size():
				selected_index = new_index
				color_selector.highlight(selected_index)
				_apply_color(selected_index)

	# --- WASD or Arrow Key Selection ---
	elif selecting_color and event is InputEventKey and event.pressed:
		var dir: Vector2 = Vector2.ZERO

		match event.keycode:
			KEY_W, KEY_UP:
				dir = Vector2(0, -1)
			KEY_D, KEY_RIGHT:
				dir = Vector2(1, 0)
			KEY_S, KEY_DOWN:
				dir = Vector2(0, 1)
			KEY_A, KEY_LEFT:
				dir = Vector2(-1, 0)

		if dir != Vector2.ZERO:
			var dirs: Array[Vector2] = [
				Vector2(0, -1),  # up
				Vector2(1, 0),   # right
				Vector2(0, 1),   # down
				Vector2(-1, 0)   # left
			]

			var best_index: int = 0
			var best_dot: float = -INF
			for i in range(dirs.size()):
				var dot: float = dir.dot(dirs[i])
				if dot > best_dot:
					best_dot = dot
					best_index = i

			if best_index != selected_index and best_index < unlocked_colors.size():
				selected_index = best_index
				color_selector.highlight(selected_index)
				_apply_color(selected_index)

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
	shader_mat.set_shader_parameter("outline_color", total_colors[unlocked_colors[index]])

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

func unlock_color(index: int) -> void:
	if index not in unlocked_colors and index >= 0 and index < total_colors.size():
		unlocked_colors.append(index)
		print("Unlocked new color:", total_colors[index])
		color_selector.colors = _get_unlocked_color_list()

	# little bounce effect
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.1)
	
	# GET RID OF THIS ONCE COLOR SYSTEM IS GLOBAL!!
	get_tree().root.set_meta("unlocked_colors", unlocked_colors)
	
func _get_unlocked_color_list() -> Array[Color]:
	var list: Array[Color] = []
	for i in unlocked_colors:
		if i >= 0 and i < total_colors.size():
			list.append(total_colors[i])
	return list

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
	var color_names = ["RED", "GREEN", "BLUE", "YELLOW", "WHITE"]
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
			"YELLOW": color = Color.YELLOW
			"WHITE": color = Color.WHITE

		# Skip white platforms entirely
		if name == "WHITE":
			continue

		# Active layer (matches player color)
		if color.is_equal_approx(current_color):
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
	set_collision_mask_value(16, true) # deathpit

	var c: Color = current_color
	if c.is_equal_approx(Color.RED):
		set_collision_mask_value(2, true)
	elif c.is_equal_approx(Color.GREEN):
		set_collision_mask_value(4, true)
	elif c.is_equal_approx(Color.BLUE):
		set_collision_mask_value(3, true)
	elif c.is_equal_approx(Color.YELLOW):
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
	shader_mat.set_shader_parameter("outline_color", current_color)
