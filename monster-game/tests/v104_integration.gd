extends SceneTree
var checks = 0
var failures = 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("V104_FAIL " + label)
	else: print("V104_OK ", label)
func fresh() -> HordeRun:
	var r = HordeRun.new()
	r.start_developer("animation_check", 1, 0, 104)
	r.members[0].kind = 2; r.members[0].arrival = 0.0
	return r
func run() -> void:
	var g = load("res://main.tscn").instantiate(); root.add_child(g)
	g.test_mode = true; g.set_process(false); g.set_physics_process(false)
	g.data = MonsterCatalog.defaults(); g.hub.update(g, 0.01)
	var sprite = g.actor.masked_approved
	expect(sprite.has_assets(), "all six approved masked atlases and grip points load")
	for state in ["idle", "run", "rise", "fall", "capture", "push", "panic"]:
		expect(g.actor.renderer_for(2, state, 0.0) == "masked_approved", "approved masked renderer for " + state)
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(HordeMaskedApprovedSprite.ROOT + "manifest.json"))
	for clip in HordeMaskedApprovedSprite.TIMINGS:
		var total = 0
		for ms in HordeMaskedApprovedSprite.TIMINGS[clip]: total += ms
		expect(total == int(manifest.clips[clip].duration_ms), "art timing preserved: " + clip)
	var neutral = sprite.textures.andando.get_image().get_region(Rect2i(0, 0, 512, 512)).get_data()
	for clip in ["pulo", "virar_veiculo", "dano", "captura"]:
		expect(sprite.texture_for_frame(clip,0).get_image().get_region(Rect2i(0, 0, 512, 512)).get_data() == neutral, "seamless neutral entry: " + clip)
		expect(sprite.texture_for_frame(clip,1) == sprite.textures[clip], "approved action frames preserved: " + clip)
	expect(HordeMaskedApprovedSprite.draw_rect(156.8).size.is_equal_approx(HordeMaskedApprovedSprite.draw_rect(112).size * 1.4), "one body scale for every pose and the enlarged power")
	var r = fresh(); g.runner = r
	r.jump()
	expect(float(r.members[0].vy) < 0.0, "jump responds immediately without waiting for anticipation art")
	var landed = false
	for i in range(180):
		r.advance(1.0 / 120.0, i < 15)
		if float(r.members[0].land_left) > 0.0:
			landed = true
			expect(is_equal_approx(r.members[0].land_left, HordeMaskedApprovedSprite.LANDING_SECONDS), "actual touchdown starts the entire landing animation")
			break
	expect(landed, "masked jump returns to solid ground")
	r = fresh(); g.runner = r
	var captive = r.add_entity("civilian", HordeRun.ANCHOR + 40)
	r.begin_capture(captive, r.members[0])
	expect(is_equal_approx(captive.capture_duration, 0.62) and g.animation_state(r.members[0]) == "capture", "masked capture keeps normal gameplay duration")
	for i in range(45): r.update_civilians(1.0 / 60.0)
	expect(captive.taken and r.souls == 1 and r.active_count() == 2, "capture awards exactly one soul and recruit")
	r = fresh(); g.runner = r
	var soldier = r.add_entity("soldier", HordeRun.ANCHOR + 40)
	r.begin_capture(soldier, r.members[0])
	expect(is_equal_approx(soldier.capture_duration, 0.82), "soldier capture retains its dedicated timing")
	r = fresh(); g.runner = r
	var car = r.add_entity("car", HordeRun.ANCHOR + 175)
	car.contacts[r.members[0].id] = 4
	var passengers = car.passengers.size()
	r.flip_vehicle(car)
	expect(r.cars == 1 and r.souls == passengers and r.coins == MonsterCatalog.VEHICLES.car.reward, "flip rewards and rescued passengers remain unchanged")
	expect(is_equal_approx(r.members[0].mask_flip_left, HordeMaskedApprovedSprite.FLIP_SECONDS) and g.animation_state(r.members[0]) == "push", "successful flip starts the approved action")
	r.flip_vehicle(car)
	expect(r.cars == 1 and r.souls == passengers, "animation never repeats flip rewards")
	r = fresh(); g.runner = r; r.shields = 1
	r.damage(0, "bullet")
	expect(r.members.size() == 1 and r.loss_causes.is_empty() and g.animation_state(r.members[0]) == "panic", "protected damage plays the new reaction without recording a death")
	r.hit_grace = 0.0; r.damage(0, "bullet")
	expect(r.loss_causes.get("bullet", 0) == 1 and r.dead, "unprotected soldier shot records its actual cause once")
	var fx = HordeEffects.new(); fx.death(2, Vector2(200, 420))
	expect(fx.deaths[0].pos == Vector2(200, 420) and is_equal_approx(fx.deaths[0].duration, 0.8), "damage animation preserves elevated or airborne position")
	var empty = HordeProfileUI.loss_entries({})
	expect(empty.size() == 12, "all twelve causes remain visible before the first loss")
	var sample = HordeProfileUI.loss_entries({"fall":15.0, "camera":12, "air_bomb":3, "rushing_car":1, "car":2, "vehicle":3, "collapse":1})
	var total = 0
	for entry in sample: total += int(entry.count)
	expect(total == 37 and sample[0].count == 16 and sample[11].count == 5, "legacy causes merge into clear labels without losing totals")
	var historical = HordeProfileUI.loss_entries({"impact":2, "old_custom_cause":3})
	expect(historical.size() == 13 and historical[-1].count == 5, "unmapped historical losses stay visible")
	expect(HordeProfileUI.count_text(15.0) == "15" and HordeProfileUI.count_text(0.0) == "0", "counts have no fractional suffix")
	for width in [960, 1280, 1600]:
		var view = Rect2(0, 0, width, 720)
		var body = Rect2(60, 165, width - 120, 455)
		var d = HordeProfileUI.losses_layout(body)
		var fits = true
		for card in d.cards: fits = fits and body.encloses(card) and card.size.x >= 200
		var buttons = HordeProfileUI.footer_layout(view)
		fits = fits and not buttons[0].intersects(buttons[1]) and not buttons[1].intersects(buttons[2])
		expect(fits, "loss cards and three touch targets fit width " + str(width))
	g.data.death_causes = {"fall":15,"camera":12,"air_bomb":3,"rushing_car":1}
	g.perform_action("profile_open")
	expect(g.screen == "profile" and g.hub.profile_page == 0, "profile opens from the real menu action")
	g.perform_action("causes_open")
	expect(g.hub.profile_page == 1, "losses toggle opens all cause cards")
	g.perform_action("causes_open"); g.perform_action("back")
	expect(g.screen == "home", "overview and back navigation remain connected")
	g.queue_free(); g = null
	for i in range(3): await process_frame
	print("V104_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
