extends Area2D
@export var is_start: bool = true
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))
	print("[TimerController] Ready:", name)

	# Pick correct animation based on toggle
	if is_start:
		sprite.play("start")
	else:
		sprite.play("end")

func _on_body_entered(body: Node) -> void:
	if not body is CharacterBody2D:
		return
	print("[TimerController] Triggered:", name)

	# Find the TimerUI Control node
	var ui_layer := get_tree().current_scene.find_child("TimerUI", true, false)
	var ui = null
	if ui_layer:
		ui = ui_layer.get_node_or_null("TimerUI")  # the Control child inside the CanvasLayer

	if ui == null:
		print("[TimerController] TimerUI script node not found.")
		return

	# Start or stop the timer based on flag
	if is_start:
		print("[TimerController] Starting timer...")
		ui.start_timer()
	else:
		print("[TimerController] Stopping timer...")
		ui.stop_timer()
