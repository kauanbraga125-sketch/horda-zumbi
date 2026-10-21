extends SceneTree
var game
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output = OS.get_environment("HORDA_VALIDATION_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://main.tscn").instantiate();root.add_child(game)
	game.test_mode = true;game.capture_mode = true;game.set_process(false);game.set_physics_process(false)
	var index = 0
	var first_frame = maxi(0, int(OS.get_environment("HORDA_CAPTURE_START")))
	for level in [0, 3]:
		game.data = MonsterCatalog.defaults();game.data.wallet = 269;game.data.eyes = 8
		game.data.levels.horde = level;game.data.owned.append(1);game.data.stock.double_horde = 1
		game.perform_action("play");game.perform_action("select_object_double_horde")
		for frame in range(48):
			game.prepare_ui.update(game, 1.0 / 12.0)
			if index >= first_frame: await game.capture_frame(output.path_join("frame-%04d.png" % index))
			index += 1
	print("V109_MOTION_READY frames=", index)
	game.queue_free();game = null
	for i in range(3): await process_frame
	quit()
