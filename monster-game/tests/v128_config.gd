extends SceneTree
func _initialize() -> void:
	assert(str(ProjectSettings.get_setting("application/config/version"))=="0.10.28")
	var error=ProjectSettings.save_custom("res://.godot/v128-project.binary")
	print("V128_CONFIG_",error)
	quit(error)
