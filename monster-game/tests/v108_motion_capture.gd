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
	for id in game.prepare_ui.ORDER:
		game.data = MonsterCatalog.defaults();game.data.wallet = 269;game.data.eyes = 8;game.data.levels.horde = 1
		game.data.stock[id] = 1;game.perform_action("play")
		if game.prepare_ui.ORDER.find(id) >= 5: game.perform_action("prepare_next")
		game.perform_action("select_object_" + id)
		for frame in range(36):
			game.prepare_ui.update(game, 1.0 / 18.0)
			if index >= first_frame: await game.capture_frame(output.path_join("frame-%04d.png" % index))
			index += 1
	print("V108_MOTION_READY frames=", index)
	game.queue_free();game = null
	for i in range(3): await process_frame
	quit()
