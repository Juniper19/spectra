extends Area2D

@export_file("*.tscn") var target_scene: String
@export var spawn_point_name: String = ""
@export var prompt_text: String = "↑ Enter"

var player_in_range: Node = null
@onready var prompt_label: Label = $Label

func _ready() -> void:
	# set label text dynamically
	prompt_label.text = prompt_text
	prompt_label.visible = false
	prompt_label.modulate.a = 0.0

	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _on_body_entered(body: Node) -> void:
	if body.name == "MyPlayer":
		player_in_range = body
		_show_prompt(true)

func _on_body_exited(body: Node) -> void:
	if body == player_in_range:
		player_in_range = null
		_show_prompt(false)

func _process(_delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("up"):
		if target_scene != "":
			get_tree().root.set_meta("next_spawn_point", spawn_point_name)
			get_tree().change_scene_to_file(target_scene)

# Fade the prompt label in/out
func _show_prompt(visible: bool) -> void:
	var tween := create_tween()
	tween.tween_property(prompt_label, "modulate:a", (1.0 if visible else 0.0), 0.2)
	if visible:
		prompt_label.visible = true
	else:
		await tween.finished
		prompt_label.visible = false
