@tool
extends Area2D

@export var orb_color: Color = Color.RED:
	set(value):
		orb_color = value
		if Engine.is_editor_hint():
			modulate = value

@export var boost_force: float = 420.0  # matches your normal jump_force or slightly higher
var player_in_area: CharacterBody2D = null

func _ready() -> void:
	modulate = orb_color
	if not Engine.is_editor_hint():
		connect("body_entered", Callable(self, "_on_body_entered"))
		connect("body_exited", Callable(self, "_on_body_exited"))

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_area = body

func _on_body_exited(body: Node) -> void:
	if body == player_in_area:
		player_in_area = null

func _process(_delta: float) -> void:
	# only boost if player is overlapping + presses jump + color matches
	if player_in_area and Input.is_action_just_pressed("up"):
		var player := player_in_area
		if "current_color" in player and player.current_color.is_equal_approx(orb_color):
			_apply_jump_boost(player)

func _apply_jump_boost(player: CharacterBody2D) -> void:
	# overwrite the vertical velocity (like a jump reset)
	player.velocity.y = -boost_force

	# little squash + stretch animation
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(self, "scale", Vector2(1.3, 0.8), 0.05).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE)
