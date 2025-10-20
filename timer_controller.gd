extends Area2D
@export var is_start: bool = true

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))
	print("[TimerController] Ready:", name)

func _on_body_entered(body: Node) -> void:
	if not body is CharacterBody2D:
		return
	print("[TimerController] Triggered:", name)

	var ui_layer := get_tree().current_scene.find_child("TimerUI", true, false)
	var ui = null
	if ui_layer:
		ui = ui_layer.get_node_or_null("TimerUI")  # the Control child inside the CanvasLayer

	if ui == null:
		print("[TimerController] TimerUI script node not found.")
		return

	# now these actually run
	if is_start:
		print("[TimerController] Starting timer...")
		ui.start_timer()
	else:
		print("[TimerController] Stopping timer...")
		ui.stop_timer()
