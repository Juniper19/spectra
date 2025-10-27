extends Control


func _on_start_pressed() -> void:
	print("start")
	get_tree().change_scene_to_file("res://ColorLevel.tscn")
	pass # Replace with function body.

func _on_settings_pressed() -> void:
	print("settings")
	pass # Replace with function body.

func _on_exit_pressed() -> void:
	print("exit")
	get_tree().quit()
	pass # Replace with function body.
