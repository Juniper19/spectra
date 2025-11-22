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
@export var apex_gravity_scale: float = 0.7
@export var apex_threshold: float = 40.0

var spawn_position: Vector2
var is_build_mode: bool = false
var was_on_floor: bool = false
var is_crouching: bool = false


# ---------------- Color Settings ----------------
@export var total_colors: Array[Color] = [
	Color("#B4202A"), # red
	Color("#14A02E"), # green
	Color("#249FDE"), # blue
	Color("#F9A31B")  # yellow
]

var unlocked_colors: Array[int] = [1]
var current_color_index: int = 0

var current_color: Color:
	get:
		return total_colors[unlocked_colors[current_color_index]]

# ---------------- UI & Sprite References ----------------
var selecting_color := false
var selected_index := -1
@onready var color_selector = $"../UI/ColorSelector"
@onready var sprite: AnimatedSprite2D = $PlayerArt

# ---------------- Flow Meter ----------------
var flow_meter: float = 0.0
@export var flow_gain_rate: float = 1
@export var flow_decay_rate: float = 10.0
@export var max_flow: float = 6.0
@export var base_speed: float = 165.0
@export var flow_idle_grace: float = 0.3

# ---------------- Flow Start Delay ----------------
@export var flow_start_delay: float = 2.0
var flow_timer: float = 0.0
var flow_enabled: bool = false

var flow_idle_timer: float = 0.0
@onready var vignette_mat: ShaderMaterial = $FlowVisualizer/Vignette.material

# ---------------- Lifecycle ----------------
func _ready() -> void:
	# sync global color unlocks
	if get_tree().root.has_meta("unlocked_colors"):
		unlocked_colors = get_tree().root.get_meta("unlocked_colors")
	else:
		get_tree().root.set_meta("unlocked_colors", unlocked_colors)

	if unlocked_colors.is_empty():
		unlocked_colors.append(0)
		current_color_index = 0
	else:
		current_color_index = clamp(current_color_index, 0, unlocked_colors.size() - 1)

	base_speed = speed

	# change player color
	($PlayerArt.material as ShaderMaterial).set_shader_parameter("tint_color", current_color)

	update_collision_masks()

	# spawn point override
	var spawn_name = get_tree().root.get_meta("next_spawn_point") if get_tree().root.has_meta("next_spawn_point") else null
	if spawn_name:
		var spawn_node = get_tree().current_scene.get_node_or_null("SpawnPoints/" + str(spawn_name))
		if spawn_node:
			global_position = spawn_node.global_position
			spawn_position = global_position
		get_tree().root.remove_meta("next_spawn_point")
	else:
		spawn_position = global_position

	color_selector.visible = false

	color_selector.colors = _get_unlocked_color_list()
	color_selector.highlight(current_color_index)

	flow_timer = 0.0
	flow_enabled = false

func _physics_process(delta: float) -> void:
	var on_floor_now := is_on_floor()
	var just_landed := (not was_on_floor) and on_floor_now
	was_on_floor = on_floor_now

	# FLOW START DELAY
	if not flow_enabled:
		flow_timer += delta
		if flow_timer >= flow_start_delay:
			flow_enabled = true

	# Jump buffer
	if Input.is_action_just_pressed("up"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

	# Gravity + apex
	if not on_floor_now:
		var gravity_force: float = gravity

		if abs(velocity.y) < apex_threshold:
			gravity_force *= apex_gravity_scale

		if velocity.y > 0:
			gravity_force *= 1.4

		velocity.y += gravity_force * delta

		if velocity.y < 0 and Input.is_action_just_released("up"):
			velocity.y *= jump_cut_multiplier
	else:
		velocity.y = 0

	# Coyote time
	if on_floor_now:
		coyote_timer = coyote_time
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	# BUILD MODE MOVEMENT
	if is_build_mode:
		velocity.x = 0.0
		jump_buffer_timer = 0.0

		if not on_floor_now:
			if sprite.animation != "jump":
				sprite.play("jump")
		else:
			if sprite.animation != "idle":
				sprite.play("idle")

		velocity.y += gravity * delta
		move_and_slide()

		flow_enabled = false
		flow_timer = 0.0
		flow_meter = 0.0
		return

	# NORMAL MOVEMENT
	var direction: float = Input.get_axis("left", "right")

	if direction != 0:
		if sign(velocity.x) != sign(direction) and abs(velocity.x) > 10.0:
			velocity.x = direction * min(abs(velocity.x), speed)
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# Flip sprite
	if direction != 0:
		sprite.flip_h = direction < 0

	# ---------------- CROUCH LOGIC ----------------
	is_crouching = (
		Input.is_action_pressed("down")
		and on_floor_now
		and abs(velocity.x) < 5.0
	)

	# ---------------- ANIMATION ----------------
	if not on_floor_now:
		# AIRBORNE
		if is_about_to_land():
			if sprite.animation != "land" and sprite.animation != "jump":
				sprite.play("land")
		else:
			if sprite.animation != "jump":
				sprite.play("jump")

	else:
		# ON FLOOR
		if just_landed:
			sprite.play("land")

		elif sprite.animation == "land":
			pass

		# CROUCH
		elif is_crouching:
			if sprite.animation != "crouch":
				sprite.play("crouch")

		# WALK
		elif abs(velocity.x) > 5:
			if sprite.animation != "walk":
				sprite.play("walk")

		# IDLE
		else:
			if sprite.animation != "idle":
				sprite.play("idle")

	# Jump logic
	if jump_buffer_timer > 0.0 and (on_floor_now or coyote_timer > 0.0):
		velocity.y = -jump_force
		coyote_timer = 0.0
		jump_buffer_timer = 0.0

		if abs(velocity.x) > speed * 0.8:
			velocity.x *= 1.1

	# FLOW LOGIC (unchanged)
	if flow_enabled:
		var fps: int = Engine.physics_ticks_per_second
		var real_delta: float = (1.0 / fps) if fps > 0 else delta

		if on_floor_now:
			var dir_val: float = Input.get_axis("left", "right")
			var touching_wall: bool = false

			for i in range(get_slide_collision_count()):
				var collision := get_slide_collision(i)
				if collision.get_normal().x != 0.0:
					if sign(collision.get_normal().x) == -sign(dir_val):
						touching_wall = true
						break

			var moving: bool = (abs(velocity.x) > 5.0) and (not touching_wall)

			if dir_val != 0.0 and moving:
				flow_idle_timer = 0.0
				flow_meter = clampf(flow_meter + flow_gain_rate * real_delta, 0.0, max_flow)
			else:
				flow_idle_timer += real_delta
				if flow_idle_timer > flow_idle_grace:
					flow_meter = clampf(flow_meter - flow_decay_rate * real_delta, 0.0, max_flow)

	if flow_enabled and flow_meter <= 0.0:
		flow_enabled = false
		flow_timer = 0.0

	var flow_multiplier: float = 1.0 + (flow_meter / max_flow) * 0.7
	speed = base_speed * flow_multiplier

	var target_intensity: float = flow_meter / max_flow
	var current_intensity: float = vignette_mat.get_shader_parameter("intensity")
	vignette_mat.set_shader_parameter("intensity", lerp(current_intensity, target_intensity, 5.0 * delta))

	var current_vc: Color = vignette_mat.get_shader_parameter("color")
	var target_vc: Color = total_colors[unlocked_colors[current_color_index]]
	vignette_mat.set_shader_parameter("color", current_vc.lerp(target_vc, 5.0 * delta))

	move_and_slide()
	check_deathpit()

func is_about_to_land() -> bool:
	if velocity.y <= 0:
		return false
	if velocity.y < 40:
		return false

	var motion := Vector2(0, min(10, velocity.y * get_physics_process_delta_time()))
	return test_move(transform, motion)


# LAND animation exit
func _on_PlayerArt_animation_finished() -> void:
	if sprite.animation == "land":
		if abs(velocity.x) > 5:
			sprite.play("walk")
		else:
			sprite.play("idle")

# ---------------- Color Selector Input ----------------
var mouse_selecting := false
var mouse_center: Vector2
var mouse_start_position: Vector2
var drag_threshold: float = 30.0

func _unhandled_input(event: InputEvent) -> void:
	if is_build_mode:
		return

	# RMB held → selector
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and not mouse_selecting:
			if unlocked_colors.size() <= 1:
				return

			mouse_selecting = true
			selecting_color = true
			selected_index = current_color_index
			color_selector.visible = true
			color_selector.colors = _get_unlocked_color_list()
			color_selector.set_meta("camera", $Camera2D)
			await get_tree().process_frame
			color_selector.highlight(selected_index)
			Engine.time_scale = 0.2

		elif not event.pressed and mouse_selecting:
			mouse_selecting = false
			selecting_color = false
			color_selector.visible = false
			Engine.time_scale = 1.0

	# Mouse selection movement
	elif event is InputEventMouseMotion and mouse_selecting:
		var selector_center: Vector2 = color_selector.get_global_transform_with_canvas().origin + color_selector.size / 2.0
		var delta_vec: Vector2 = event.position - selector_center
		if delta_vec.length() > 20.0:
			var angle: float = atan2(delta_vec.y, delta_vec.x)
			var new_index: int = _direction_to_index(angle)
			if new_index != selected_index and new_index < unlocked_colors.size():
				selected_index = new_index
				color_selector.highlight(selected_index)
				_apply_color(selected_index)

	# Keyboard color selection
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
				Vector2(0, -1),
				Vector2(1, 0),
				Vector2(0, 1),
				Vector2(-1, 0)
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
				_apply_color(best_index)

func _direction_to_index(angle: float) -> int:
	var drag_dir := Vector2(cos(angle), sin(angle))
	var dirs := [
		Vector2(0, -1),
		Vector2(1, 0),
		Vector2(0, 1),
		Vector2(-1, 0)
	]

	var best_index := 0
	var best_dot := -INF
	for i in range(dirs.size()):
		var dot := drag_dir.dot(dirs[i])
		if dot > best_dot:
			best_dot = dot
			best_index = i

	return best_index

# ---------------- Color Handling ----------------
func _apply_color(index: int) -> void:
	current_color_index = index
	update_collision_masks()
	push_out_of_tiles()

	var mat := $PlayerArt.material as ShaderMaterial
	mat.set_shader_parameter("tint_color", total_colors[unlocked_colors[index]])

	play_color_swap_effect()

func play_color_swap_effect() -> void:
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(sprite, "scale", Vector2(0.8, 1.2), 0.05).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.05).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.05).set_trans(Tween.TRANS_SINE)

func unlock_color(index: int) -> void:
	if index not in unlocked_colors and index >= 0 and index < total_colors.size():
		unlocked_colors.append(index)
		color_selector.colors = _get_unlocked_color_list()

	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.1)

	get_tree().root.set_meta("unlocked_colors", unlocked_colors)

func _get_unlocked_color_list() -> Array[Color]:
	var list: Array[Color] = []
	for i in unlocked_colors:
		if i >= 0 and i < total_colors.size():
			list.append(total_colors[i])
	return list

# ---------------- Collision Pushout ----------------
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

# ---------------- Collision Masks ----------------
func update_collision_masks() -> void:
	set_collision_mask_value(1, true)   # base collisions
	set_collision_mask_value(2, false) # red
	set_collision_mask_value(3, false) # blue
	set_collision_mask_value(4, false) # green
	set_collision_mask_value(5, false) # yellow
	set_collision_mask_value(16, true) # death pit

	var id := unlocked_colors[current_color_index]

	match id:
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
	($PlayerArt.material as ShaderMaterial).set_shader_parameter("tint_color", current_color)

# ---------------- Build Mode ----------------
func set_build_mode(active: bool) -> void:
	is_build_mode = active

	if active:
		if mouse_selecting or selecting_color:
			mouse_selecting = false
			selecting_color = false
			color_selector.visible = false
			selected_index = current_color_index
			Engine.time_scale = 1.0
