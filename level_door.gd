extends Area2D

@export_file("*.tscn") var target_scene: String
@export var spawn_point_name: String = ""  # where the player should appear in the target scene

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
	if body.name == "MyPlayer":
		if target_scene != "":
			# Store spawn info globally before changing scenes
			get_tree().root.set_meta("next_spawn_point", spawn_point_name)
			get_tree().change_scene_to_file(target_scene)
