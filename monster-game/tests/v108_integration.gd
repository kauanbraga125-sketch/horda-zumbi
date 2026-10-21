extends SceneTree
class SaveBlockedGame:
	extends "res://scripts/game.gd"
	var block_saves = false
	func save_game(path: String = SAVE_PATH) -> bool:
		if block_saves: return false
		return super.save_game(path)
var checks = 0
var failures = 0
var g
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1;push_error("V108_FAIL " + note)
	else: print("V108_OK ", note)
func run() -> void:
	g = load("res://main.tscn").instantiate();root.add_child(g)
	g.test_mode = true;g.set_process(false);g.set_physics_process(false)
	for item in HordeMeta.OBJECTS:
		g.data = MonsterCatalog.defaults();g.data.stock[item.id] = 1;g.perform_action("play")
		var wallet: int = g.data.wallet
		g.perform_action("select_object_" + item.id)
		expect(g.data.stock[item.id] == 0 and g.prepare_ui.selected(g, item.id), "last unit activates immediately: " + item.id)
		var event_count: int = g.prepare_ui.feedback.events.size()
		for i in range(50): g.perform_action("select_object_" + item.id)
		expect(g.data.stock[item.id] == 0 and g.data.prepared_items == [item.id] and g.prepare_ui.feedback.events.size() == event_count, "repeated taps neither remove nor charge nor replay: " + item.id)
		g.prepare_ui.update(g, 0.55)
		expect(not g.prepare_ui.feedback.event_for(item.id).is_empty() and g.runner.entities.is_empty() and g.data.wallet == wallet, "distinct feedback is cosmetic and cannot award currency: " + item.id)
		g.prepare_ui.update(g, 3.0)
		expect(g.prepare_ui.feedback.events.is_empty() and g.prepare_ui.selected(g, item.id), "burst expires while the bonus remains armed: " + item.id)
	g.data = MonsterCatalog.defaults();g.data.stock = {"double_horde":3, "power_mask":2, "power_fly":2, "civil_pack":2}
	for item in HordeMeta.OBJECTS:
		if not g.data.stock.has(item.id): g.data.stock[item.id] = 0
	g.perform_action("play");g.perform_action("select_object_double_horde");g.perform_action("select_object_power_mask");g.perform_action("select_object_power_fly");g.perform_action("select_object_civil_pack")
	expect(g.data.stock.power_mask == 1 and g.data.stock.power_fly == 2 and "power_fly" not in g.data.prepared_items, "first transformation is final for the next run")
	expect(g.prepare_ui.preview.members.size() == 2 and g.prepare_ui.preview.entities.is_empty(), "doubling previews new members without spawning the civilian encounter")
	var stock: Dictionary = g.data.stock.duplicate(true)
	g.perform_action("objects_open");g.perform_action("back");g.perform_action("back");g.perform_action("play")
	expect(g.data.stock == stock and g.data.prepared_items.size() == 3 and g.prepare_ui.feedback.events.is_empty(), "market, home and reopen retain armed bonuses without replaying effects")
	var path = "user://v108_prepared_items_test.json"
	expect(g.save_game(path), "pending bonuses can be saved with the real atomic save writer")
	var restored: Dictionary = g.validate_save(JSON.parse_string(FileAccess.get_file_as_string(path)))
	expect(restored.prepared_items == g.data.prepared_items and restored.stock == stock, "restarting from the saved JSON preserves the activation and exact stock")
	g.data = restored;g.prepare_ui.enter(g)
	g.perform_action("select_object_double_horde")
	expect(g.prepare_ui.feedback.events.is_empty() and g.data.stock == stock, "restart cannot replay or debit a previous activation")
	var active: Dictionary = HordeMeta.prepared_inventory(g.data)
	g.perform_action("commit_play")
	expect(g.screen == "run" and g.runner.run_items == active and g.runner.members.size() == 2 and g.data.stock == stock, "start transfers all armed bonuses exactly once with no second stock debit")
	expect(g.data.prepared_items.is_empty(), "handoff clears the next-run activation ledger")
	g.perform_action("commit_play");g.perform_action("play")
	expect(g.data.stock == stock and g.data.prepared_items.is_empty() and g.prepare_ui.preview.members.size() == 1, "a later preparation cannot reuse the previous run's bonuses")
	g.perform_action("select_object_double_horde")
	expect(g.data.stock.double_horde == 1 and g.data.prepared_items == ["double_horde"], "a new run may activate one new unit of the same bonus")
	var legacy = MonsterCatalog.defaults();legacy.erase("prepared_items");legacy.stock.double_horde = 4;legacy.wallet = 987
	restored = g.validate_save(legacy)
	expect(restored.prepared_items.is_empty() and restored.stock.double_horde == 4 and restored.wallet == 987, "older saves migrate without spending or granting a bonus")
	legacy.prepared_items = ["double_horde", "double_horde", false, "fake", "power_mask", "power_fly", "power_shield"]
	restored = g.validate_save(legacy)
	expect(restored.prepared_items == ["double_horde", "power_mask", "power_shield"], "save validation removes duplicate, unknown and conflicting activation records")
	legacy.prepared_items = 50
	expect(g.validate_save(legacy).prepared_items.is_empty(), "malformed activation state is normalized safely")
	var fail_game = SaveBlockedGame.new();root.add_child(fail_game)
	fail_game.test_mode = true;fail_game.set_process(false);fail_game.set_physics_process(false)
	fail_game.data = MonsterCatalog.defaults();fail_game.data.stock.double_horde = 1;fail_game.perform_action("play");fail_game.block_saves = true
	fail_game.perform_action("select_object_double_horde")
	expect(fail_game.data.stock.double_horde == 1 and fail_game.data.prepared_items.is_empty() and fail_game.prepare_ui.feedback.events.is_empty(), "failed activation save rolls back stock, bonus and animation")
	fail_game.block_saves = false;fail_game.perform_action("select_object_double_horde");fail_game.block_saves = true
	fail_game.perform_action("commit_play")
	expect(fail_game.screen == "prepare" and fail_game.data.prepared_items == ["double_horde"] and fail_game.data.stock.double_horde == 0, "failed handoff save keeps the paid bonus ready and does not start a run")
	fail_game.block_saves = false;fail_game.perform_action("commit_play")
	expect(fail_game.screen == "run" and fail_game.runner.run_items.has("double_horde") and fail_game.data.stock.double_horde == 0, "retry after a handoff failure applies the original unit without another debit")
	fail_game.queue_free()
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(path + suffix)
	print("V108_RESULT checks=", checks, " failures=", failures)
	g.queue_free();g = null
	for i in range(3): await process_frame
	quit(1 if failures else 0)
