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
			game.press_at(button.rect.get_center(), 109);game.release_touch(109);return
	failures += 1;push_error("V109_MISSING_TOUCH_TARGET " + action)
func run() -> void:
	output = OS.get_environment("HORDA_VALIDATION_DIR");DirAccess.make_dir_recursive_absolute(output)
	game = load("res://main.tscn").instantiate();root.add_child(game)
	game.test_mode = true;game.capture_mode = true;game.set_process(false);game.set_physics_process(false)
	for variant in ["single", "full", "mask", "fly"]:
		game.data = MonsterCatalog.defaults();game.data.wallet = 269;game.data.eyes = 8
		game.data.stock = {"double_horde":1, "power_mask":1, "power_fly":1}
		game.data.levels.horde = 3 if variant == "full" else 0;game.data.owned.append(1)
		game.perform_action("play")
		if variant in ["mask", "fly"]:
			game.data.power_levels.mask_size = 1 if variant == "mask" else 0
			await tap("prepare_next");await tap("select_object_power_" + variant)
			game.prepare_ui.update(game, 2.7);await tap("prepare_previous")
		await tap("select_object_double_horde")
		var previous = 0.0
		for age in [0.25, 0.65, 1.05, 1.55, 2.1, 2.65, 3.4]:
			game.prepare_ui.update(game, age - previous);previous = age
			await shot(variant + "_" + str(int(age * 100)))
		await tap("select_object_double_horde")
		if not game.prepare_ui.feedback.events.is_empty() or game.data.stock.double_horde != 0: failures += 1
		await tap("commit_play");await shot(variant + "_started")
		if game.prepare_ui.feedback.ritual.back.visible or game.prepare_ui.feedback.ritual.front.visible: failures += 1
	for id in ["civil_pack", "double_coins", "bonus_time", "power_shield", "power_boost"]:
		game.data = MonsterCatalog.defaults();game.data.wallet = 269;game.data.eyes = 8;game.data.stock[id] = 1
		game.perform_action("play")
		if game.prepare_ui.ORDER.find(id) >= 5: await tap("prepare_next")
		await tap("select_object_" + id);game.prepare_ui.update(game, 1.15)
		await shot(id)
	print("V109_VISUAL_RESULT failures=", failures)
	game.queue_free();game = null
	for i in range(3): await process_frame
	quit(1 if failures else 0)
