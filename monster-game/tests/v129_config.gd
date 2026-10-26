extends SceneTree
func _initialize() -> void:
	assert(str(ProjectSettings.get_setting("application/config/version"))=="0.10.29")
	var error=ProjectSettings.save_custom("res://.godot/v129-project.binary")
	print("V129_CONFIG_",error)
	quit(error)
