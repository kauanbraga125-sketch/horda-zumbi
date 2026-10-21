extends SceneTree
var checks = 0
var failures = 0
var game
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1;push_error("V109_FAIL " + note)
	else: print("V109_OK ", note)
func run() -> void:
	game = load("res://main.tscn").instantiate();root.add_child(game)
	game.test_mode = true;game.set_process(false);game.set_physics_process(false)
	for level in range(4):
		game.data = MonsterCatalog.defaults();game.data.levels.horde = level;game.data.stock.double_horde = 2
		game.perform_action("play");game.perform_action("select_object_double_horde")
		game.prepare_ui.update(game, 0.85);game.configure_layout()
		var ritual = game.prepare_ui.feedback.ritual
		expect(ritual.back.visible and ritual.front.visible, "mist layers participate during summon, upgrade " + str(level))
		expect(game.prepare_ui.preview.members.size() == (1 + level) * 2 and game.prepare_ui.preview.entities.is_empty(), "summon uses exact initial horde without generating encounters " + str(level))
		var age: float = game.prepare_ui.feedback.events[0].age
		game.perform_action("select_object_double_horde")
		expect(game.data.stock.double_horde == 1 and game.prepare_ui.feedback.events[0].age == age, "repeated input cannot charge or restart the longer animation " + str(level))
		game.perform_action("commit_play")
		expect(not ritual.back.visible and not ritual.front.visible and game.screen == "run" and game.runner.members.size() == (1 + level) * 2, "starting mid-animation hides all cinematic layers and applies the full horde " + str(level))
	game.data = MonsterCatalog.defaults();game.data.stock.double_horde = 1;game.perform_action("play");game.perform_action("select_object_double_horde")
	game.prepare_ui.update(game, 0.65);game.configure_layout()
	var age: float = game.prepare_ui.feedback.events[0].age
	game.perform_action("objects_open")
	expect(not game.prepare_ui.feedback.ritual.back.visible and not game.prepare_ui.feedback.ritual.front.visible, "market hides the ritual layers")
	game.perform_action("back")
	expect(game.prepare_ui.feedback.events[0].age == age and game.data.stock.double_horde == 0, "market return continues the existing animation without charging")
	game.perform_action("back");game.perform_action("play")
	expect(game.prepare_ui.feedback.events.is_empty() and game.prepare_ui.preview.members.size() == 2 and not game.prepare_ui.feedback.ritual.back.visible, "new visit shows the armed horde without replaying the ceremony")
	for i in range(20): game.perform_action("back");game.perform_action("play")
	expect(game.world_canvas.get_child_count() == 2 and game.foreground_canvas.get_child_count() == 1, "repeated visits reuse the two mist nodes without growing the scene")
	game.data = MonsterCatalog.defaults();game.data.stock.double_horde = 1;game.perform_action("play");game.perform_action("select_object_double_horde")
	var before: Dictionary = game.data.duplicate(true)
	game.prepare_ui.update(game, 4.0);game.configure_layout()
	expect(game.prepare_ui.feedback.events.is_empty() and not game.prepare_ui.feedback.ritual.back.visible and not game.prepare_ui.feedback.ritual.front.visible, "settled animation releases its GPU layers")
	expect(game.data == before and game.prepare_ui.preview.entities.is_empty(), "ceremony cannot change wallet, missions or activated inventory")
	print("V109_RESULT checks=", checks, " failures=", failures)
	game.queue_free();game = null
	for i in range(3): await process_frame
	quit(1 if failures else 0)
