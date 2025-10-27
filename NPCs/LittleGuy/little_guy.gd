extends Area2D

@export var dialogue_file: DialogueResource
@export var prompt_text: String = "E: Talk"

var player_in_range: Node = null
@onready var prompt_label: Label = $Label

func _ready() -> void:
	# initialize label
	prompt_label.text = prompt_text
	prompt_label.visible = false
	prompt_label.modulate.a = 0.0

	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = body
		_show_prompt(true)

func _on_body_exited(body: Node) -> void:
	if body == player_in_range:
		player_in_range = null
		_show_prompt(false)

func _process(_delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("interact"):
		_show_prompt(false)
		_start_dialogue()

# ------------------------
# Dialogue and prompt logic
# ------------------------
func _start_dialogue() -> void:
	DialogueManager.show_dialogue_balloon(dialogue_file)

	# connect to the active balloon to freeze player while talking
	await get_tree().process_frame
	if DialogueManager.has_node("Balloon"):
		var balloon = DialogueManager.get_node("Balloon")
		balloon.connect("balloon_started", Callable(player_in_range, "_on_dialogue_started"))
		balloon.connect("balloon_finished", Callable(player_in_range, "_on_dialogue_finished"))

# fade the prompt label in/out
func _show_prompt(visible: bool) -> void:
	var tween := create_tween()
	tween.tween_property(prompt_label, "modulate:a", (1.0 if visible else 0.0), 0.2)
	if visible:
		prompt_label.visible = true
	else:
		await tween.finished
		prompt_label.visible = false
