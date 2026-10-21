extends SceneTree
var failures = 0
var checks = 0

func _initialize() -> void: call_deferred("suite")
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1;push_error("V101_FAIL "+message)
	else: print("V101_OK ",message)

func fresh() -> HordeRun:
	var run = HordeRun.new();run.start(MonsterCatalog.defaults().levels,913)
	run.entities.clear();run.events.clear();run.next_segment = 99999
	return run

func suite() -> void:
	var g = load("res://main.tscn").instantiate();root.add_child(g)
	g.test_mode = true;g.set_process(false);g.set_physics_process(false)
	g.data = MonsterCatalog.defaults();g.hub.update(g,0.01)
	var data = MonsterCatalog.defaults();data.stock.power_fly = 2;data.stock.power_mask = 3;data.stock.power_shield = 1
	for id in ["power_mask", "power_fly", "power_shield"]: HordeMeta.activate_preparation(data, id)
	var active = HordeMeta.prepared_inventory(data)
	expect(active.has("power_mask") and not active.has("power_fly") and active.has("power_shield"),"only one starting transformation is committed")
	expect(data.stock.power_fly == 2 and data.stock.power_mask == 2 and data.stock.power_shield == 0,"unchosen transformation stock is preserved")
	g.data = data;g.change_screen("prepare");g.hub.action(g,"select_object_power_fly")
	expect("power_mask" in g.data.prepared_items and "power_fly" not in g.data.prepared_items and g.data.stock.power_fly == 2,"touch cannot replace an already activated transformation")
	var run = fresh();var original_owned = run.power_owned.duplicate()
	run.configure_items({"power_mask":true,"power_shield":true},false)
	expect(run.shields == 1 and run.opening_power == 2 and 2 in run.power_owned,"temporary powers are ready for the run")
	run.elapsed = 1.3;run.update_meta_run()
	expect(run.opening_power == -1 and run.transform_kind == 2 and run.transform_left > 0,"starting power enters the approved transformation")
	run.transform_left = 0;run.update_meta_run()
	expect(run.transform_left == 0,"starting transformation does not retrigger")
	run.start(MonsterCatalog.defaults().levels,913)
	expect(run.power_owned == original_owned and run.opening_power == -1 and run.shields == 0,"single-run rewards do not unlock permanently or leak into another run")
	run = fresh();run.levels.frenzy = 1;run.configure_items({"power_boost":true},false)
	expect(run.boost_left == HordeTuning.BOOST_SECONDS and run.boost_protected(),"starting impulse uses existing protected boost mechanics")
	data = MonsterCatalog.defaults();data.wallet = 8000
	expect(HordeMeta.equip_cosmetic(data,"bruxa") and data.wallet == 6200 and data.equipped_hat == "bruxa","new hat can be purchased and equipped")
	HordeMeta.equip_cosmetic(data,"bruxa");HordeMeta.equip_cosmetic(data,"bruxa")
	expect(data.wallet == 6200 and data.cosmetics.count("bruxa") == 1 and data.equipped_hat == "bruxa","equipping owned cosmetic never charges twice")
	var rng = RandomNumberGenerator.new();rng.seed = 77119
	var seen = {};var jackpots = 0;var cosmetics = {}
	for i in range(20000):
		var prize = HordeMeta.reward(rng)
		if prize.type == "object": seen[prize.id] = true
		if prize.type == "coins" and int(prize.amount) >= 2000: jackpots += 1
		if prize.type == "cosmetic": cosmetics[prize.id] = true
	expect(seen.size() == HordeMeta.OBJECTS.size(),"grave pool can award all ten objects including four powers")
	expect(cosmetics.size() == 3 and jackpots > 100 and jackpots < 300,"all cosmetics and rare large treasure occur in seeded sample")
	print("V101_REWARDS sample=20000 jackpots=",jackpots)
	data = MonsterCatalog.defaults();HordeMeta.add_grave_pair(data,rng)
	data.graves[0].rewards[0] = {"type":"object","id":"power_mask","amount":1,"label":"MÁSCARA"}
	data.graves[0].rewards[1] = {"type":"cosmetic","id":"bruxa","amount":1,"label":"BRUXA"}
	for i in range(106): data.graves[0].clean[0].append(i);data.graves[0].clean[1].append(i)
	HordeMeta.claim_grave(data,0);HordeMeta.claim_grave(data,1)
	var restored = g.validate_save(JSON.parse_string(JSON.stringify(data)))
	expect(restored.stock.power_mask == 1 and "bruxa" in restored.cosmetics,"new rewards survive save reload")
	expect(restored.graves[0].rewards == data.graves[0].rewards and restored.graves[0].claimed == [true,true],"existing grave prizes and claims remain fixed during migration")
	HordeMeta.claim_grave(restored,0);HordeMeta.claim_grave(restored,1)
	expect(restored.stock.power_mask == 1 and restored.cosmetics.count("bruxa") == 1,"reopening a grave does not repeat new rewards")
	run = fresh();var enemy = run.add_entity("soldier",HordeRun.ANCHOR+40)
	run.begin_capture(enemy,run.members[0]);var initial_shots = run.shots
	expect(is_equal_approx(enemy.capture_duration,0.82) and enemy.state == "capture","soldier gets a readable dedicated capture duration")
	for i in range(60): run.advance(1.0/60.0)
	expect(run.shots == initial_shots and enemy.taken and run.souls == 1 and run.active_count() == 2,"capture disables shots and grants exactly one soul and recruit")
	run = fresh();run.perk_kind = 3;run.perk_left = 9
	enemy = run.add_entity("soldier",HordeRun.ANCHOR+40);run.begin_capture(enemy,run.members[0])
	expect(is_equal_approx(enemy.capture_duration,HordeFlyApprovedSprite.CAPTURE_SECONDS),"soldier capture preserves the approved fly timing")
	g.data = MonsterCatalog.defaults();g.data.player_level = 75;g.change_screen("book")
	g.hub.update(g,0.01);g.hub.update(g,1.0)
	expect(g.hub.book_phase == 1.0 and g.hub.book_opened,"four relics open the book through its new animation")
	g.hub.action(g,"book_touch");g.hub.update(g,1.0)
	expect(g.hub.book_phase == 0.0 and not g.hub.book_opened,"book can close again without erasing signature or relics")
	g.queue_free();await process_frame
	print("V101_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
