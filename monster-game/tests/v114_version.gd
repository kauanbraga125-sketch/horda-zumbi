extends SceneTree
func _initialize() -> void:
	var version = str(ProjectSettings.get_setting("application/config/version"))
	if version != "0.10.14":
		push_error("Unexpected runtime version: "+version)
		quit(1)
		return
	print("V114_RUNTIME_VERSION_OK ",version)
	quit()
