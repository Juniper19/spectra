@tool
extends Area2D

@export var color_index: int = 0
@export var boost_force: float = 450.0
@export var respawn_time: float = 2.0  # seconds before orb returns

var player_in_area: CharacterBody2D = null
var sprite: Node2D


func _ready() -> void:
	# tint orb using the player's palette (only works in-game)
	if Engine.is_editor_hint():
		# in editor, show exported color index as gray placeholder
		modulate = Color(1,1,1)
	else:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var p = players[0]
			modulate = p.total_colors[color_index]

	if not Engine.is_editor_hint():
		connect("body_entered", Callable(self, "_on_body_entered"))
		connect("body_exited", Callable(self, "_on_body_exited"))

	var sprite_candidate := get_node_or_null("Sprite2D")
	sprite = sprite_candidate if sprite_candidate else get_node_or_null("AnimatedSprite2D")


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_area = body


func _on_body_exited(body: Node) -> void:
	if body == player_in_area:
		player_in_area = null


func _process(_delta: float) -> void:
	if player_in_area and Input.is_action_just_pressed("up"):
		var player := player_in_area

		# COLOR MATCH BY INDEX, NOT RGB
		var player_color_id: int = player.unlocked_colors[player.current_color_index]
		if player_color_id == color_index:
			_apply_jump_boost(player)


func _apply_jump_boost(player: CharacterBody2D) -> void:
	player.velocity.y = -boost_force
	_flash_and_hide()


func _flash_and_hide() -> void:
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(self, "scale", Vector2(1.3, 0.8), 0.05).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2).set_delay(0.1)
	tween.tween_callback(Callable(self, "_on_hide_complete"))


func _on_hide_complete() -> void:
	visible = false
	set_process(false)
	await get_tree().create_timer(respawn_time).timeout
	_respawn()


func _respawn() -> void:
	modulate.a = 0.0
	visible = true
	set_process(true)

	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
