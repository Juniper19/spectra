@tool
extends ColorRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # don’t eat clicks
	_sync_effect_toggle()

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_READY:
		_sync_effect_toggle()

func _sync_effect_toggle() -> void:
	var mat := material as ShaderMaterial
	if mat:
		# Off in editor, on in game
		mat.set_shader_parameter("enable_effect", not Engine.is_editor_hint())
