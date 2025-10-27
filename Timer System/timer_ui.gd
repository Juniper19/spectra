extends Control

var timer_running := false
var time_elapsed := 0.0

@onready var label: Label = $TimerLabel

func _process(delta: float) -> void:
	if timer_running:
		time_elapsed += delta
		label.text = "%.2f" % time_elapsed

func start_timer() -> void:
	time_elapsed = 0.0
	timer_running = true
	visible = true

func stop_timer() -> void:
	timer_running = false
	visible = true  # keep visible to show final time
	label.text = "%.2f" % time_elapsed

func reset_timer() -> void:
	timer_running = false
	time_elapsed = 0.0
	label.text = "0.00"
	visible = false
