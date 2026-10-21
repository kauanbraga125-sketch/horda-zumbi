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
			game.press_at(button.rect.get_center(), 107);game.release_touch(107);return
	failures += 1;push_error("V107_MISSING_TOUCH_TARGET " + action)
func run() -> void:
	output = OS.get_environment("HORDA_VALIDATION_DIR");DirAccess.make_dir_recursive_absolute(output)
	game = load("res://main.tscn").instantiate();root.add_child(game)
	game.test_mode = true;game.capture_mode = true;game.set_process(false);game.set_physics_process(false)
	game.data = MonsterCatalog.defaults();game.data.wallet = 240;game.data.eyes = 8;game.data.stock = {"double_horde":1}
	game.hub.update(game, 0.0);game.perform_action("play")
	await shot("prepare_single")
	game.prepare_ui.update(game, 0.7);await shot("prepare_scrolled")
	await tap("select_object_double_horde");game.prepare_ui.update(game, 0.0)
	await shot("prepare_double")
	if game.prepare_ui.preview.members.size() != 2 or game.data.stock.double_horde != 0: failures += 1
	await tap("prepare_next");await shot("prepare_powers_empty")
	for item in HordeMeta.OBJECTS: game.data.stock[item.id] = 3
	await tap("select_object_power_mask");await tap("select_object_power_shield")
	game.prepare_ui.update(game, 0.3);await shot("prepare_mask_shield")
	game.data.power_levels.mask_size = 1;await shot("prepare_giant_mask")
	game.data.power_levels.mask_size = 0
	game.data.prepared_items.erase("power_mask")
	await tap("select_object_power_fly");game.prepare_ui.update(game, 0.3)
	await shot("prepare_fly")
	if "power_mask" in game.data.prepared_items or "power_fly" not in game.data.prepared_items: failures += 1
	await tap("prepare_previous");game.data.prepared_items.clear();game.data.levels.horde = 3;game.data.owned.append(1)
	await tap("select_object_double_horde");game.prepare_ui.update(game, 0.3)
	await shot("prepare_upgraded_horde")
	game.data.levels.horde = 0;game.data.prepared_items.clear();game.prepare_ui.update(game, 0.0)
	await shot("prepare_all_in_stock")
	await tap("objects_open");await shot("market_from_prepare");await tap("back")
	if game.screen != "prepare": failures += 1
	await tap("commit_play");await shot("actual_game_started")
	if game.screen != "run" or game.runner.world_px != 0: failures += 1
	game.perform_action("play");game.data.stock.clear();game.prepare_ui.update(game, 0.0)
	await shot("prepare_empty")
	print("V107_VISUAL_RESULT failures=", failures)
	game.queue_free();game = null
	for i in range(3): await process_frame
	quit(1 if failures else 0)
