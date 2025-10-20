extends Area2D

@export_file("*.tscn") var target_scene: String
@export var spawn_point_name: String = ""

var player_in_range: Node = null

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _on_body_entered(body: Node) -> void:
	if body.name == "MyPlayer":  # updated name
		player_in_range = body

func _on_body_exited(body: Node) -> void:
	if body == player_in_range:
		player_in_range = null

func _process(_delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("up"):
		if target_scene != "":
			get_tree().root.set_meta("next_spawn_point", spawn_point_name)
			get_tree().change_scene_to_file(target_scene)
