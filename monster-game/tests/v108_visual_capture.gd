extends SceneTree
var game
var output = ""
var failures = 0
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	game.toast_left = 0
	await game.capture_frame(output.path_join(name + ".png"))
func tap(action: String) -> void:
	game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	for button in game.buttons:
		if button.action == action:
			game.press_at(button.rect.get_center(), 108);game.release_touch(108);return
	failures += 1;push_error("V108_MISSING_TOUCH_TARGET " + action)
func run() -> void:
	output = OS.get_environment("HORDA_VALIDATION_DIR");DirAccess.make_dir_recursive_absolute(output)
	game = load("res://main.tscn").instantiate();root.add_child(game)
	game.test_mode = true;game.capture_mode = true;game.set_process(false);game.set_physics_process(false)
	for item in HordeMeta.OBJECTS:
		game.data = MonsterCatalog.defaults();game.data.wallet = 269;game.data.eyes = 8
		game.data.stock[item.id] = 1;game.data.levels.horde = 1;game.perform_action("play")
		if item.id in ["bonus_time", "power_fly", "power_mask", "power_shield", "power_boost"]: await tap("prepare_next")
		await tap("select_object_" + item.id)
		if game.data.stock[item.id] != 0: failures += 1
		var previous = 0.0
		for age in [0.15, 0.45, 0.8, 1.25, 2.0]:
			game.prepare_ui.update(game, age - previous);previous = age
			await shot(item.id + "_" + str(int(age * 100)))
		await tap("select_object_" + item.id)
		if not game.prepare_ui.feedback.events.is_empty() or game.data.stock[item.id] != 0: failures += 1
		await tap("objects_open");await tap("back");await tap("back");await tap("play")
		if not game.prepare_ui.selected(game, item.id): failures += 1
	game.data = MonsterCatalog.defaults();game.data.wallet = 269;game.data.eyes = 8
	for item in HordeMeta.OBJECTS: game.data.stock[item.id] = 2
	game.perform_action("play")
	for id in ["civil_pack", "coin_bombs", "coin_cars", "double_coins", "double_horde"]: await tap("select_object_" + id)
	game.prepare_ui.update(game, 0.6);await shot("combined_bonuses")
	await tap("prepare_next")
	for id in ["bonus_time", "power_mask", "power_shield", "power_boost"]: await tap("select_object_" + id)
	game.data.power_levels.mask_size = 1;game.prepare_ui.update(game, 0.6);await shot("combined_giant_mask")
	game.prepare_ui.update(game, 2.0);await shot("armed_giant_mask")
	var stock: Dictionary = game.data.stock.duplicate(true)
	await tap("commit_play");await shot("actual_game_started")
	if game.screen != "run" or game.data.stock != stock or game.runner.run_items.size() != 9: failures += 1
	print("V108_VISUAL_RESULT failures=", failures)
	game.queue_free();game = null
	for i in range(3): await process_frame
	quit(1 if failures else 0)
