extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var boot = load("res://boot.tscn").instantiate()
	root.add_child(boot)
	current_scene = boot
	var game: Node
	for attempt in range(120):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.has_method("start_run"):
			game = current_scene
			break
	if not is_instance_valid(game):
		push_error("PACKAGED_BOOT_FAILED: main game was not loaded")
		quit(1)
		return
	for i in range(8): await process_frame
	var report = JSON.parse_string(FileAccess.get_file_as_string("user://horda_boot_diagnostico.json"))
	var valid = report is Dictionary and str(report.get("status", "")) == "scene_loaded" and str(report.get("version", "")) == str(ProjectSettings.get_setting("application/config/version"))
	if valid:
		print("PACKAGED_BOOT_OK version=", report.version, " files=", report.files_checked)
	else: push_error("PACKAGED_BOOT_FAILED: startup audit was not completed")
	# Let scene/audio resources retire before shutting down the test engine.
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.set_enabled(false)
	game.queue_free()
	current_scene = null
	game = null
	boot = null
	for i in range(8): await process_frame
	quit(0 if valid else 1)
