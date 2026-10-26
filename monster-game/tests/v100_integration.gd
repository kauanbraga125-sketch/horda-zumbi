extends SceneTree
var checks = 0
var failures = 0
var g

func _initialize() -> void:
	call_deferred("suite")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1;push_error("V100_FAIL " + message)

func fresh_run() -> HordeRun:
	var run = HordeRun.new();run.start(MonsterCatalog.defaults().levels, 442)
	run.entities.clear();run.events.clear()
	return run

func suite() -> void:
	g = load("res://main.tscn").instantiate();root.add_child(g)
	g.test_mode = true;g.set_process(false);g.set_physics_process(false)
	g.data = MonsterCatalog.defaults();g.hub.update(g, 0.01)
	var legacy = MonsterCatalog.defaults();legacy.version = 6;legacy.wallet = 8800;legacy.power_owned = [3,2]
	legacy.power_levels.mask_shield = 1;legacy.power_levels.mask_force = 2;legacy.player_level = 12;legacy.level_souls = 381
	legacy.ritual_progress = 80
	legacy.total_souls = 1256;legacy.areas = [0,1,2,3]
	var migrated = g.validate_save(legacy)
	expect(migrated.version == 7 and migrated.wallet == 8800 and migrated.player_level == 12, "migration preserves level/wallet")
	expect(migrated.power_levels.mask_shield == 1 and migrated.power_levels.mask_force == 2 and migrated.areas.size() == 4, "migration preserves non-prefix upgrades and areas")
	expect(not migrated.ritual_pending.is_empty() and migrated.ritual_ready, "legacy ritual essence preserved")
	var chain = HordeMeta.chain(migrated, 2)
	expect(chain.level == 4 and MonsterCatalog.POWER_UPGRADES[int(chain.next.index)].id == "mask_time", "chain skips purchased upgrades without removing them")
	var data = MonsterCatalog.defaults();var rng = RandomNumberGenerator.new();rng.seed = 1934
	data.altar_souls = 75
	var report = HordeProgress.settle(data, 333, rng)
	expect(data.altar_souls == 8 and data.graves.size() == 4 and report.graves == 4, "altar overflow grants four pairs")
	expect(data.player_level == 1 and data.level_souls == 0 and data.total_souls == 333, "souls do not grant mission XP")
	var pair = data.graves[0].duplicate(true)
	data.graves[0].rewards[0] = {"type":"eyes", "amount":3, "label":"3 OLHOS"}
	for i in range(105): data.graves[0].clean[0].append(i)
	expect(HordeMeta.claim_grave(data,0).is_empty(), "grave threshold prevents early award")
	data.graves[0].clean[0].append(105)
	expect(not HordeMeta.claim_grave(data,0).is_empty() and data.eyes == 3, "grave award once")
	expect(HordeMeta.claim_grave(data,0).is_empty() and data.eyes == 3, "grave cannot double claim")
	data.graves[0].started = true
	expect(not HordeMeta.sell_graves(data), "cannot sell opened pair")
	data.graves = [pair]
	expect(HordeMeta.sell_graves(data) and data.graves.is_empty(), "unopened pair sells")
	expect(HordeMeta.claim_daily(data,200000) and data.eyes == 8, "daily gift grants five")
	expect(not HordeMeta.claim_daily(data,200001) and not HordeMeta.claim_daily(data,100000), "daily gift cannot repeat or clock rollback")
	expect(HordeMeta.claim_daily(data,286400) and data.eyes == 13, "gift available after 24h")
	data = MonsterCatalog.defaults();data.wallet = 1000
	expect(HordeMeta.buy_object(data,"double_coins") and data.wallet == 700 and data.stock.double_coins == 1, "purchase stores consumable")
	var selected: Array = ["double_coins", "double_coins", "missing"]
	for id in selected: HordeMeta.activate_preparation(data, id)
	var active = HordeMeta.prepared_inventory(data)
	expect(active.size() == 1 and data.stock.double_coins == 0, "consume only one unit per selected type")
	expect(HordeMeta.activate_preparation(data, "double_coins") == "active" and data.stock.double_coins == 0, "used bonus cannot consume stock again")
	var pending = {"key":"m:1", "title":"TEST", "ritual":44}
	HordeProgress.queue_mission(data,pending);HordeProgress.queue_mission(data,pending)
	expect(data.ritual_pending.size() == 1, "mission credit deduplicates")
	HordeProgress.ritual(data,rng)
	expect(data.player_level == 2 and data.eyes == 3, "first level awards three eyes")
	HordeProgress.ritual(data,rng)
	expect(data.eyes == 3, "level reward not repeated")
	var rare_count = 0;rng.seed = 123456
	for i in range(100000):
		if rng.randf() < HordeMeta.EYE_RUN_CHANCE: rare_count += 1
	expect(rare_count > 2000 and rare_count < 2450, "rare roll averages 1/45")
	print("V100_RARITY occurrences=",rare_count," /100000 probability=",HordeMeta.EYE_RUN_CHANCE)
	var run = fresh_run();run.configure_items({"double_horde":true,"bonus_time":true},true)
	expect(run.active_count() == 2, "double starting horde")
	run.elapsed = 9;run.update_meta_run();var eyes = 0
	for e in run.entities:
		if e.kind == "eye": eyes += 1
	expect(eyes == 5 and not run.rare_pending, "rare expedition creates exactly five eyes")
	run.update_meta_run();expect(run.entities.size() == 5, "rare expedition does not repeat")
	run.activate_perk(3)
	expect(run.perk_left >= HordeTuning.BASE_POWER_SECONDS + 15, "consumable adds 15 seconds")
	run = fresh_run();var enemy = run.add_entity("soldier",1000)
	var modes = {};var last_shots = 0
	for i in range(480):
		run.soldier.update(run,enemy,1.0/60.0)
		if run.shots > last_shots:
			var bullet = run.entities[-1];modes[bullet.shot_mode] = true
			expect(Vector2(bullet.x,bullet.y).distance_to(run.soldier.muzzle(enemy)) < 0.01, "shot originates at current muzzle")
			expect(float(bullet.homing_left) == 0, "no homing after firing")
			last_shots = run.shots
	expect(modes.has("rocket") and modes.has("high") and modes.has("tracking"), "three weapons shoot in sequence")
	var before_shots = run.shots;enemy.state = "capture"
	for i in range(180): run.soldier.update(run,enemy,1.0/60.0)
	expect(run.shots == before_shots, "capture cancels shots")
	run = fresh_run();run.dead = true;run.members.clear();run.add_entity("gap",0,HordeRun.FLOOR,0,900);run.add_entity("bomb",400)
	run.revive_horde(5)
	expect(run.active_count() == 5 and not run.dead and run.hit_grace == 3, "safe five-monster revive")
	for e in run.entities: expect(e.taken, "revive removes imminent danger")
	g.data = MonsterCatalog.defaults();g.runner = run;g.screen = "run";g.revive_used = false;g.revive_offered = false;g.run_settled = false;g.end_delay = -1
	run.dead = true;g.finish_run()
	expect(g.screen == "revive" and not g.run_settled and g.data.runs == 0, "death offers revive before settling")
	g.perform_action("revive_free")
	expect(g.screen == "run" and g.runner.active_count() == 1 and g.revive_used, "free revive works without ad")
	run.dead = true;g.finish_run();g.finish_run()
	expect(g.run_settled and g.data.runs == 1, "final settlement runs once")
	g.end_delay = -1
	if DisplayServer.get_name() != "headless": await visuals()
	await additional_checks()
	expect(checks >= 53, "all transaction tests completed")
	g.queue_free()
	await process_frame
	print("V100_RESULT checks=",checks," failures=",failures)
	call_deferred("finish_tests")

func visuals() -> void:
	g.set_process(true)
	g.toast_left = 0
	g.data = MonsterCatalog.defaults();g.data.wallet = 6543;g.data.eyes = 32;g.data.level_souls = 33;g.hub.shown_xp = 33;g.hub.shown_level = 1
	g.data.stock = {"coin_bombs":2,"coin_cars":1,"bonus_time":1,"double_horde":2,"civil_pack":3,"double_coins":1}
	g.runner = fresh_run();g.end_delay = -1
	for page in ["home","market","prepare","missions","graves","book","profile","revive","results"]:
		if page == "graves": HordeMeta.add_grave_pair(g.data,RandomNumberGenerator.new())
		if page == "results": g.run_report = {"old_altar":74,"graves":1};g.runner.souls = 42;g.result_time = 5
		g.change_screen(page);g.hub.update(g,0.016)
		g.queue_redraw();g.world_canvas.queue_redraw();g.foreground_canvas.queue_redraw()
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var image = root.get_texture().get_image()
		image.save_png("res://../validation/" + page + ".png")
		expect(not g.buttons.is_empty(), "screen buttons " + page)
	g.market.open(1);g.change_screen("market");g.queue_redraw();g.market_canvas.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../validation/market_upgrades.png")
	g.data.player_level = 75;g.hub.progress_notice_left = 0;g.change_screen("book")
	await create_timer(0.10).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../validation/book_signature.png")
	g.data.player_level = 1;g.hub.progress_notice_left = 4.0
	for weapon in ["bazooka", "transition", "revolver", "sniper"]:
		g.runner = fresh_run();g.runner.view_right = 1250
		var enemy = g.runner.add_entity("soldier",840)
		enemy.weapon = weapon;enemy.weapon_t = 0.71 if weapon == "bazooka" else 0.30 if weapon == "transition" else 0.65 if weapon == "revolver" else 0.96
		enemy.weapon_rate = 1.0;enemy.soldier_phase = "attack";enemy.aim_angle = deg_to_rad(8);enemy.flash = 0.08
		var bullet = g.runner.add_entity("bullet",650,510);bullet.shot_mode = "rocket";bullet.age = 0.1
		var blast = g.runner.add_entity("soldier_blast",700,550);blast.age = 0.18
		g.change_screen("run");g.queue_redraw();g.world_canvas.queue_redraw();g.foreground_canvas.queue_redraw()
		await create_timer(0.10).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../validation/soldier_" + weapon + ".png")


func additional_checks() -> void:
	# Input, persistence and post-revive transactions are checked independently.
	g.set_process(false);g.end_delay = -1;g.data = MonsterCatalog.defaults()
	g.data.eyes = 30;g.runner = fresh_run();g.runner.dead = true;g.screen = "revive";g.revive_used = false
	g.perform_action("revive_paid");g.perform_action("revive_paid")
	expect(g.data.eyes == 5 and g.runner.active_count() == 5, "paid revive consumes 25 once on repeated input")
	g.data.stock = {"double_horde":2};g.screen = "prepare";g.perform_action("select_object_double_horde")
	var previous_world = g.runner.world_px;g._physics_process(1.0)
	expect(g.runner.world_px == previous_world, "preparation freezes world")
	g.perform_action("commit_play");g.perform_action("commit_play")
	expect(g.data.stock.double_horde == 1 and g.runner.active_count() == 2, "double Play cannot consume two units")
	g.data.stock = {"double_coins":1};g.screen = "prepare";g.perform_action("select_object_double_coins")
	g.perform_action("back")
	expect(g.data.stock.double_coins == 0 and "double_coins" in g.data.prepared_items, "leaving preserves an already used bonus for the next run")
	g.runner = fresh_run();g.runner.coins = 2;g.runner.run_items = {"double_coins":true}
	g.runner.events.assign([{"type":"coin","amount":2,"x":300,"y":500}]);var wallet_before = int(g.data.wallet)
	g.consume_run_events()
	expect(g.runner.coins == 4 and g.data.wallet == wallet_before + 4, "double coins stacks correctly with frenzy")
	g.data.graves.clear();var rng = RandomNumberGenerator.new();rng.seed = 84721;HordeMeta.add_grave_pair(g.data,rng)
	g.screen = "graves"
	var rect = g.hub.clean_rect(g.hub.grave_rects(g)[0])
	var event = InputEventScreenTouch.new();event.pressed = true;event.index = 0;event.position = g.to_global(rect.position + Vector2(8,8))
	expect(g.hub.input(g,event), "grave accepts touchscreen brush")
	for row in range(16):
		for col in range(12):
			var drag = InputEventScreenDrag.new();drag.index = 0;drag.position = g.to_global(rect.position + (Vector2(col,row)+Vector2.ONE*.5)*rect.size/Vector2(12,16));g.hub.input(g,drag)
	event.pressed = false;g.hub.input(g,event)
	expect(g.data.graves[0].claimed[0] and not g.data.graves[0].claimed[1], "brush claims only cleaned side")
	var serialized = JSON.parse_string(JSON.stringify(g.data));var restored = g.validate_save(serialized)
	expect(restored.graves[0].claimed[0] and not restored.graves[0].claimed[1] and restored.graves[0].rewards == g.data.graves[0].rewards, "grave state and prizes survive save round trip")
	g.data.player_level = 75;g.screen = "book";g.hub.name_edit.text = "Kauan";g.hub.signature_points = [{"x":.1,"y":.2,"new":true},{"x":.3,"y":.4,"new":false},{"x":.6,"y":.3,"new":false}]
	g.perform_action("book_sign");var signed = g.validate_save(JSON.parse_string(JSON.stringify(g.data)))
	expect(signed.book_name == "Kauan" and signed.book_signature.size() == 3 and not signed.book_signed_at.is_empty(), "book signature saved")
	var run = fresh_run();var rocket = run.add_entity("bullet",HordeRun.ANCHOR,HordeRun.FLOOR-30);rocket.shot_mode = "rocket"
	var count = run.members.size();run.soldier.explode(run,rocket);var after = run.members.size();run.soldier.explode(run,rocket)
	expect(after == count - 1 and run.members.size() == after, "rocket explosion damages once")
	run = fresh_run();run.perk_kind = 2;run.perk_left = 5;rocket = run.add_entity("bullet",HordeRun.ANCHOR,HordeRun.FLOOR-30);rocket.shot_mode = "rocket"
	run.soldier.explode(run,rocket)
	expect(run.active_count() == 1, "mask protection survives new rocket mechanics")
	# The real moving encounter must reach the sniper before the horde captures him.
	run = fresh_run();run.next_segment = 99999;run.hit_grace = 100.0
	var moving_enemy = run.add_entity("soldier",840);var actual_modes = {}
	for i in range(600):
		run.advance(1.0/60.0)
		for projectile in run.entities:
			if projectile.kind == "bullet": actual_modes[str(projectile.get("shot_mode", ""))] = true
		if run.dead: break
	expect(actual_modes.has("rocket") and actual_modes.has("high") and actual_modes.has("tracking"), "moving encounter has enough time for all three weapons")
	# The sniper locks for >= .35 seconds and never changes the angle in that window.
	run = fresh_run();var enemy = run.add_entity("soldier",1000);run.soldier.update(run,enemy,0.01)
	enemy.weapon = "sniper";enemy.weapon_t = 0.0;enemy.weapon_rate = 1.8;enemy.weapon_fired = false;enemy.soldier_phase = "attack"
	for i in range(34): run.soldier.update(run,enemy,1.0/60)
	var angle = float(enemy.aim_angle);run.members[0].y -= 180
	for i in range(18): run.soldier.update(run,enemy,1.0/60)
	expect(run.shots == 0 and is_equal_approx(angle,enemy.aim_angle), "locked sniper leaves reaction window even at max animation speed")
	for i in range(6): run.soldier.update(run,enemy,1.0/60)
	expect(run.shots == 1, "sniper fires after warning")

func finish_tests() -> void:
	await process_frame
	quit(1 if failures else 0)
