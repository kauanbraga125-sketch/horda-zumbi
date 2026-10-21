extends SceneTree

var checks = 0
var failures = 0
var g
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1;push_error("V107_FAIL " + note)
	else: print("V107_OK ", note)

func run() -> void:
	g = load("res://main.tscn").instantiate();root.add_child(g)
	g.test_mode = true;g.set_process(false);g.set_physics_process(false)
	g.data = MonsterCatalog.defaults();g.data.wallet = 240;g.data.eyes = 8
	g.data.stock = {"double_horde":2, "civil_pack":1, "power_fly":1, "power_mask":1, "power_shield":2}
	g.data.levels.horde = 2
	g.runner.start_developer("animation_check", 4, 2, 107)
	var actual_world: float = g.runner.world_px
	var actual_stats: Dictionary = g.runner.stats().duplicate(true)
	var entities: Array = g.runner.entities.duplicate(true)
	var members: Array = g.runner.members.duplicate(true)
	var before: Dictionary = g.data.duplicate(true)
	g.perform_action("play")
	expect(g.screen == "prepare" and g.world_canvas.visible, "Play opens the actual world canvas behind preparation")
	expect(g.prepare_ui.initial_count(g) == 3, "initial horde includes permanent upgrades")
	expect(is_equal_approx(g.world_canvas.scale.x, g.CAMERA_BASE_ZOOM * 1.12), "preparation camera is twelve percent closer than gameplay")
	expect(g.world_to_ui(Vector2(HordeRun.ANCHOR, HordeRun.FLOOR)).is_equal_approx(g.CAMERA_ANCHOR), "closer camera keeps the normal game ground and leader anchor")
	for i in range(600):
		g.prepare_ui.update(g, 1.0)
		g._physics_process(1.0)
	expect(is_equal_approx(g.prepare_ui.preview.world_px, 183000.0), "ground and parallax scroll continuously at game running speed")
	expect(g.prepare_ui.preview.entities.is_empty() and g.prepare_ui.preview.tunnels.is_empty() and not g.prepare_ui.preview.generation_started, "ten-minute preview never generates civilians, cars, coins, gaps or tunnels")
	var terrain: Array = g.prepare_ui.preview.terrain.segments
	expect(terrain.size() == 1 and terrain[0].height == 0 and terrain[0].start == -INF and terrain[0].end == INF, "flat ground remains continuous for any waiting duration")
	expect(g.data == before, "waiting leaves inventory, wallet, missions, level and saved progress unchanged")
	expect(g.runner.world_px == actual_world and g.runner.stats() == actual_stats and g.runner.entities == entities and g.runner.members == members, "preview cannot move or mutate the previous real run")
	g.perform_action("select_object_double_horde");g.prepare_ui.update(g, 0.0)
	expect(g.prepare_ui.preview.members.size() == 6 and g.data.stock.double_horde == 1, "double-horde activation spends one and previews the full horde")
	g.perform_action("select_object_double_horde");g.prepare_ui.update(g, 0.0)
	expect(g.prepare_ui.preview.members.size() == 6 and g.data.stock.double_horde == 1, "used double-horde cannot be deselected or charged again")
	g.perform_action("select_object_double_coins")
	expect("double_coins" not in g.data.prepared_items and g.data.stock.get("double_coins", 0) == 0, "an empty item cannot be selected or purchased by tapping its card")
	g.perform_action("prepare_next")
	expect(g.prepare_ui.page == 1, "second page exposes the remaining five items")
	g.perform_action("select_object_power_mask");g.perform_action("select_object_power_fly")
	expect("power_mask" in g.data.prepared_items and "power_fly" not in g.data.prepared_items and g.data.stock.power_mask == 0 and g.data.stock.power_fly == 1, "first activated transformation excludes the other without spending it")
	g.data.power_levels.mask_size = 1;g.configure_layout()
	var head: Vector2 = g.world_to_ui(Vector2(HordeRun.ANCHOR, HordeRun.FLOOR - 112 * 1.4))
	expect(head.y >= g.prepare_ui.layout(g.full_rect()).cards[0].end.y + 11.9, "giant mask preview fits below the item cards without cropping its head")
	g.data.power_levels.mask_size = 0;g.configure_layout()
	g.perform_action("select_object_civil_pack");g.prepare_ui.update(g, 2.0)
	expect(g.prepare_ui.preview.entities.is_empty(), "civilian item never spawns civilians during preparation")
	var scroll: float = g.prepare_ui.preview.world_px
	g.perform_action("objects_open")
	expect(g.screen == "market" and g.previous_page == "prepare", "View Objects opens the real market with a return to preparation")
	g.perform_action("back")
	expect(g.screen == "prepare" and g.prepare_ui.page == 1 and g.prepare_ui.preview.world_px == scroll and "power_mask" in g.data.prepared_items, "return from the market preserves preview, page and chosen items")
	g.perform_action("back")
	expect(g.screen == "home" and g.data.stock.double_horde == 1 and "power_mask" in g.data.prepared_items and not g.world_canvas.visible, "leaving keeps spent bonuses armed and hides the preview")
	g.perform_action("play")
	expect(not g.data.prepared_items.is_empty() and g.prepare_ui.page == 0 and g.prepare_ui.preview.world_px == 0, "reopening preserves used bonuses without carrying a run distance")
	g.data.prepared_items = ["double_horde"];g.data.stock.double_horde = 0;g.prepare_ui.update(g, 0.0)
	expect(g.prepare_ui.preview.members.size() == 6, "using the last unit keeps the purchased bonus active at zero stock")
	g.data.prepared_items.clear();g.data.stock.double_horde = 2;g.data.stock.civil_pack = 1;g.data.stock.power_mask = 1
	g.perform_action("select_object_double_horde");g.perform_action("select_object_civil_pack");g.perform_action("select_object_power_mask");g.perform_action("select_object_power_shield")
	var count: int = g.prepare_ui.initial_count(g)
	g.perform_action("commit_play")
	expect(g.screen == "run" and g.runner.world_px == 0 and g.runner.elapsed == 0, "Começar creates a fresh real run at zero distance and time")
	expect(g.runner.members.size() == count and count == 6, "real starting horde matches the preview count")
	expect(g.data.stock.double_horde == 1 and g.data.stock.civil_pack == 0 and g.data.stock.power_mask == 0 and g.data.stock.power_shield == 1 and g.data.stock.power_fly == 1, "Começar transfers the already paid bonuses without another charge")
	expect(g.runner.opening_power == 2 and g.runner.shields == 1 and g.runner.run_items.has("civil_pack"), "chosen transformation, shield and civilian encounter are passed to the real game")
	expect(not g.runner.entities.is_empty() and g.runner.generation_started, "normal encounters are generated only after starting")
	expect(is_equal_approx(g.world_canvas.scale.x, g.CAMERA_BASE_ZOOM), "starting restores the normal gameplay camera")
	var stock: Dictionary = g.data.stock.duplicate(true)
	g.perform_action("commit_play")
	expect(g.data.stock == stock and g.runner.elapsed == 0, "duplicate start action cannot consume another item")
	for i in range(20): g._physics_process(1.0 / 60.0)
	expect(g.runner.world_px > 0 and g.runner.elapsed > 0 and not g.runner.dead, "real gameplay advances normally after preparation")
	for width in [960, 1280, 1600, 2340]:
		var view = Rect2((1280.0 - width) * 0.5, 0, width, 720)
		var d: Dictionary = g.prepare_ui.layout(view)
		var fits = view.encloses(d.previous) and view.encloses(d.next)
		for card in d.cards:
			fits = fits and view.encloses(card) and card.end.y < g.CAMERA_ANCHOR.y - 112 * g.CAMERA_BASE_ZOOM * 1.12
		for a in range(3):
			fits = fits and view.encloses(d.footer[a])
			for b in range(a): fits = fits and not d.footer[a].intersects(d.footer[b])
		expect(fits, "five item cards, arrows and three footer buttons fit width " + str(width))
	print("V107_RESULT checks=", checks, " failures=", failures)
	g.queue_free();g = null
	for i in range(3): await process_frame
	quit(1 if failures else 0)
