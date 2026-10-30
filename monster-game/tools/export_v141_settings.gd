extends SceneTree
func _initialize() -> void:
	assert(ProjectSettings.get_setting("application/config/version")=="0.10.41")
	assert(ProjectSettings.save_custom("res://.godot/v141-project.binary")==OK)
	print("V141_SETTINGS_OK");quit()
