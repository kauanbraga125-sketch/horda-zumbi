extends SceneTree
func _initialize() -> void:
	assert(ProjectSettings.get_setting("application/config/version")=="0.10.40")
	assert(ProjectSettings.save_custom("res://.godot/v140-project.binary")==OK)
	print("V140_SETTINGS_OK");quit()
