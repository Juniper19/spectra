@tool
extends Area2D

@export var orb_color: Color:
	set(value):
		orb_color = value
		if Engine.is_editor_hint():
			modulate = value

@export var boost_force: float = 450.0
@export var respawn_time: float = 2.0

var player_in_area: CharacterBody2D = null
var sprite: Node2D
var _bob_tween: Tween = null
var _glow_tween: Tween = null
var _bob_start_y: float = 0.0
var _bob_height: float = 0.0
var _bob_speed: float = 0.0

func _ready() -> void:
	modulate = orb_color

	if not Engine.is_editor_hint():
		connect("body_entered", Callable(self, "_on_body_entered"))
		connect("body_exited", Callable(self, "_on_body_exited"))

	var sprite_candidate := get_node_or_null("Sprite2D")
	sprite = sprite_candidate if sprite_candidate else get_node_or_null("AnimatedSprite2D")

	if not Engine.is_editor_hint():
		_bob_start_y = position.y
		_bob_height = randf_range(3.5, 7.0)
		_bob_speed = randf_range(0.9, 1.9)
		_start_idle_animations()

func _start_idle_animations() -> void:
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(self, "position:y", _bob_start_y - _bob_height, _bob_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(self, "position:y", _bob_start_y, _bob_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Pulse sprite brightness — separate from self.modulate which handles fade/color
	if sprite:
		_glow_tween = create_tween().set_loops()
		_glow_tween.tween_property(sprite, "modulate", Color(1.6, 1.6, 1.6, 1.0), 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_glow_tween.tween_property(sprite, "modulate", Color.WHITE, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_area = body

func _on_body_exited(body: Node) -> void:
	if body == player_in_area:
		player_in_area = null

func _process(_delta: float) -> void:
	if player_in_area and Input.is_action_just_pressed("up"):
		var player := player_in_area
		if "current_color" in player and player.current_color.is_equal_approx(orb_color):
			_apply_jump_boost(player)

func _apply_jump_boost(player: CharacterBody2D) -> void:
	player.velocity.y = -boost_force
	_flash_and_hide()

func _flash_and_hide() -> void:
	if _bob_tween:
		_bob_tween.kill()
		_bob_tween = null
	if _glow_tween:
		_glow_tween.kill()
		_glow_tween = null

	var tween := create_tween().set_ignore_time_scale(true)
	# Spike to super bright (bloom makes it a color burst), then fade — no scale change
	tween.tween_property(self, "modulate", Color(orb_color.r * 5.0, orb_color.g * 5.0, orb_color.b * 5.0, 1.0), 0.05)
	tween.tween_property(self, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_callback(Callable(self, "_on_hide_complete"))

func _on_hide_complete() -> void:
	visible = false
	set_process(false)
	await get_tree().create_timer(respawn_time, false).timeout
	_respawn()

func _respawn() -> void:
	modulate = Color(orb_color.r, orb_color.g, orb_color.b, 0.0)
	if sprite:
		sprite.modulate = Color.WHITE
	position.y = _bob_start_y
	visible = true
	set_process(true)

	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_start_idle_animations)
