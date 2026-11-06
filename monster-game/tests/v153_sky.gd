extends "res://tests/v147_reveal.gd"

const Air = preload("res://scripts/sky_aircraft.gd")
var frames = 0
var recording = false
var routes: Array[Dictionary] = []

func tap() -> void:
	var touch = InputEventScreenTouch.new()
	touch.index = 7
	touch.position = Vector2(620, 622)
	touch.pressed = true
	game._input(touch)
	touch.pressed = false
	game._input(touch)

func skip_test() -> void:
	var r = HordeRun.new()
	r.start_developer("sky", 6, 0, 5330)
	r.developer_kind = ""
	r.world_px = 3200.0
	var original_road = r.terrain.segments.duplicate(true)
	check(r.sewer.encounter.offer(r, false, "space"), "normal encounter offers the physical trampoline")
	check(r.terrain.segments == original_road, "offering the ascent leaves the current terrain intact")
	for tick in range(360):
		r.advance(STEP)
		if not r.sky.pending: break
	check(not r.sky.pending and not r.sky.active and not r.space.active and r.flights == 0, "running past the trampoline stays in the street")
	check(not r.dead and r.active_count() == 6 and r.sewer.encounter.completed_count == 0, "skipping preserves the horde and does not complete a journey")

func pickup_sweep_test() -> void:
	var r = HordeRun.new()
	var sky = r.sky
	var m = {"id": 1, "x": 344.0, "y": -127.0}
	var before = {1: Vector2(325, 224)}
	var target = Vector2(352, 0)
	check(sky.swept_pickup(m, before, target, target + Vector2(11, 0), sky.POSES.ember),
		"an ember touched between two frames collects during a fast vertical crossing")
	check(not sky.swept_pickup(m, before, target + Vector2(110, 0), target + Vector2(121, 0), sky.POSES.ember),
		"a nearby ember outside the body stays in play")

func aircraft_entry_test() -> void:
	var hull: Rect2 = Air.SPECS[Air.PLANE].hull
	check(Air.entry(Vector2(-40, -230), Vector2(-12, 81), hull).get("side", "") == "top",
		"the feet hit the roof on a fast descent")
	check(Air.entry(Vector2(-40, 220), Vector2(-12, 76), hull).get("side", "") == "under",
		"the head hits the underside first during an ascent")
	check(Air.entry(Vector2(-280, 35), Vector2(-12, 44), hull).get("side", "") == "front",
		"the fuselage nose registers a frontal collision")
	check(Air.entry(Vector2(-280, 190), Vector2(-12, 185), hull).is_empty(),
		"passing beneath with head clearance is safe")

func launcher_ground_test() -> void:
	game.start_lab("sky", 6, 0)
	step(1.1)
	var r = game.runner
	var s = r.sky
	var centre_x = s.pad_world - r.world_px
	var floor_y: float = r.ground_y(centre_x)
	var placed = await picture()
	s.pending = false
	var bare = await picture()
	s.pending = true
	for foot in [Vector2(-90, 0), Vector2(0, 6), Vector2(93, 0)]:
		var contact: Vector2 = game.world_to_ui(Vector2(centre_x + foot.x, floor_y + foot.y)) + game.layout_origin
		var visible_pixels = 0
		for y in range(floori(contact.y), floori(contact.y) + 5):
			for x in range(roundi(contact.x) - 9, roundi(contact.x) + 10):
				var base = placed.get_pixel(x, y)
				var road = bare.get_pixel(x, y)
				if base.r - base.b > .07 and absf(base.r - road.r) + absf(base.g - road.g) + absf(base.b - road.b) > .14:
					visible_pixels += 1
		check(visible_pixels > 5, "launcher foot at %d touches the stone surface" % int(foot.x))
	check(placed.save_png(folder + "/launcher.png") == OK, "capture the launcher planted in the street")

func play_route(label: String, taps: Array, capture: bool, restart: bool = false, clip: Vector2 = Vector2.ZERO) -> Dictionary:
	if restart: game.perform_action("lab_sky_restart")
	else: game.start_lab("sky", 6, 0)
	var r = game.runner
	r.run_seed = 5330
	var s = r.sky
	var initial_count = r.active_count()
	for i in range(r.members.size()):
		r.members[i]["cosmetics_0"] = ["z_plumber"] if i == 0 else []
		r.members[i]["cosmetics_1"] = ["s_ice"] if i == 1 else []
	var height_per_frame = 0.0
	var launch_count = 0
	var landing_tick = -1
	var taps_sent = 0
	var spent = 0
	var started = false
	var touched: Array[String] = []
	var timestamps: Array[Dictionary] = []
	var civilians: Array[String] = []
	var solo: Array[String] = []
	var impacts: Array[Dictionary] = []
	var shots_fired = 0
	var shots_dodged = 0
	var shots_hit = 0
	var full_pickups = 0
	var recovery_pickups = 0
	var rescued = 0
	var rejoined = 0
	var impact_altitude = 0.0
	var fall_distance = 0.0
	var previous_foot = Vector2.ZERO
	var named_frames = [3.37, 3.88, 4.36, 8.63, 9.17, 10.22, 10.59, 10.80, 11.10, 11.41, 12.00,
		14.66, 15.22, 15.62, 18.85, 19.60, 20.00, 20.28, 20.64, 21.00]
	var next_sample = 0
	var launch_pressed = false
	for tick in range(4200):
		if not launch_pressed and s.pad_world - r.world_px - r.ANCHOR < 195.0:
			tap()
			launch_pressed = true
		if s.active and taps_sent < taps.size() and s.age >= float(taps[taps_sent]):
			var before: int = s.charges
			tap()
			spent += before - s.charges
			taps_sent += 1
		var before_impact: float = s.velocity
		var before_souls: int = r.souls
		r.advance(STEP, game.jump_held)
		for e in r.events:
			if e.type == "sky_launch":
				launch_count += 1
				check(launch_pressed and s.charges == 2 and s.altitude < 65.0, label + ": actual tap hits the pad and starts the climb at the street")
			if e.type == "sky_land":
				landing_tick = tick
			if e.type in ["sky_charge", "sky_bounce", "sky_hit"]:
				touched.append(e.prop)
			if e.type == "sky_charge":
				if e.gained == 0:
					full_pickups += 1
					check(s.charges == s.MAX_CHARGES and s.objects.any(func(obj): return obj.kind == "ember" and obj.used_at == s.age),
						label + ": an ember at full capacity is consumed without exceeding the cap")
				if e.recovery: recovery_pickups += 1
			if e.type == "sky_bounce" and e.recovery: rejoined += 1
			if e.type == "sky_grab":
				check(r.souls == before_souls and s.captures.active.any(func(person): return person.prop == e.prop and person.capture_left > .0),
					label + ": the grab starts a capture animation before adding a recruit")
			if e.type == "sky_civil":
				civilians.append(e.prop)
				if not e.passenger: solo.append(e.prop)
			if e.type == "sky_aircraft":
				impacts.append({"prop": e.prop, "side": e.side, "passengers": e.passengers, "lost": e.lost})
				if e.side == "top" and e.prop != Air.PATROL:
					check(s.velocity >= 900 and e.lost == 0 and r.souls == before_souls,
						label + ": a roof stomp boosts immediately and starts passenger animations")
				if e.side == "under" and e.prop != Air.PATROL:
					check(s.velocity < 0 and e.lost == 0 and e.passengers == 0 and s.objects.any(func(obj): return obj.kind == e.prop and obj.used_at < 0),
						label + ": underside contact blocks the rise and leaves the aircraft intact")
				if e.side == "front" and e.prop != Air.PATROL:
					check(s.velocity < 0 and e.lost == 1 and e.passengers > 0,
						label + ": frontal impact costs a member and lets the survivors capture the passengers")
			if e.type == "sky_aircraft_shot": shots_fired += 1
			if e.type == "sky_aircraft_dodge": shots_dodged += 1
			if e.type == "sky_bullet_hit": shots_hit += 1
			if e.type == "sky_recovered":
				rescued += 1
				fall_distance = maxf(fall_distance, impact_altitude - s.altitude)
				check(s.active and s.velocity > 0.0, label + ": a tap reverses the fall and keeps the journey active")
			if e.type == "sky_hit":
				impact_altitude = s.altitude
				check(s.active and s.velocity < 0.0 and s.velocity <= before_impact, label + ": impact starts a fall in the sky")
				if e.prop == "storm":
					check(s.objects.any(func(obj): return obj.kind == "storm" and obj.used_at == s.age and s.hazard_phase(obj) == "attack"), label + ": the visible bolt applies the damage")
				elif e.prop == "bat":
					check(e.get("lost", 0) == 1, label + ": the bat removes one actual member")
			if str(e.type).begins_with("sky_"):
				timestamps.append({"event": e.type, "prop": e.get("prop", ""), "side": e.get("side", ""), "video_frame": frames,
					"age": s.age, "altitude": s.altitude, "charges": s.charges, "horde": r.active_count()})
		game.update_camera(STEP)
		game.configure_layout()
		game.consume_run_events()
		game.update_run_visuals(STEP)
		game.ui_time += STEP
		game.toast_left = maxf(0.0, game.toast_left - STEP)
		var foot = game.world_to_ui(Vector2(r.members[0].x, r.members[0].y))
		if tick > 0:
			height_per_frame = maxf(height_per_frame, absf(foot.y - previous_foot.y))
		previous_foot = foot
		started = started or s.active
		if capture and tick % 2 == 0 and (clip == Vector2.ZERO or (s.active and s.age >= clip.x and s.age <= clip.y)):
			var frame = await picture(false)
			assert(frame.save_jpg(folder + "/frame-%04d.jpg" % frames, .92) == OK)
			frames += 1
		elif not recording and s.active and next_sample < named_frames.size() and s.age >= float(named_frames[next_sample]):
			var still = await picture(false)
			assert(still.save_jpg(folder + "/%s-%02d.jpg" % [label, next_sample], .94) == OK)
			next_sample += 1
		if not recording and landing_tick >= 0 and tick == landing_tick + 10:
			var impact = await picture(false)
			assert(impact.save_png(folder + "/%s-impact.png" % label) == OK)
		if landing_tick >= 0 and tick > landing_tick + 74:
			break
		if not started and not s.pending: break
	check(launch_count == 1 and landing_tick >= 0 and not s.active, label + ": one takeoff and a natural landing")
	check(initial_count == 6 and r.members.size() == initial_count + civilians.size() - r.losses and not r.dead,
		label + ": the survivors and the new recruits run on after landing")
	check(r.recruits == civilians.size() and r.souls == civilians.size(), label + ": every civil awards a recruit and a soul once")
	check(r.members.all(func(m): return absf(float(m.y) - r.ground_y(float(m.x))) < .5), label + ": members settle on the real street floor")
	check(r.sewer.encounter.completed_count == 1 and r.world_px > s.start_world + 500.0, label + ": the run advances through the handoff")
	check(height_per_frame < 35.0, label + ": camera never jumps between street and sky")
	var report = {"route": label, "peak_m": int(s.peak / 30.0), "taps_used": spent, "contacts": touched,
		"events": timestamps, "camera_delta_px": height_per_frame, "gates": s.course.gate, "losses": r.losses,
		"civilians": civilians, "full_pickups": full_pickups, "recovery_pickups": recovery_pickups,
		"rescued": rescued, "rejoined": rejoined, "fall_distance_px": fall_distance, "solo": solo, "aircraft": impacts,
		"shots_fired": shots_fired, "shots_dodged": shots_dodged, "shots_hit": shots_hit}
	routes.append(report)
	return report

func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR")
	assert(not folder.is_empty())
	recording = OS.get_environment("HORDA_SKY_RECORD") == "1"
	DirAccess.make_dir_recursive_absolute(folder)
	skip_test()
	pickup_sweep_test()
	aircraft_entry_test()
	root.size = Vector2i(1280, 720)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	game.capture_freeze = true
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.set_enabled(false)
	game.data = MonsterCatalog.defaults()
	await launcher_ground_test()
	var inputs = [1.90, 5.85, 6.80, 8.18, 13.33, 16.20, 17.85, 19.12]
	var ascent = await play_route("subida", inputs, recording)
	check(ascent.peak_m >= 155 and ascent.gates >= 7, "timed taps climb across generated gates after the recovery")
	check("ember" in ascent.contacts and "balloon" in ascent.contacts and "cloud" in ascent.contacts, "the charge and both free boosts are reachable")
	check(ascent.solo == ["para_ochre", "para_lilac", "jetpack"], "both parachutists and the jetpack pilot join the horde")
	check(ascent.full_pickups > 0, "the replay touches embers with a full charge meter")
	check("storm" in ascent.contacts and ascent.recovery_pickups > 0 and ascent.rescued >= 1 and ascent.rejoined >= 1
		and ascent.fall_distance_px > 320.0, "the storm gives a real drop with a reachable ember, tap and rescue cloud")
	check(ascent.aircraft.any(func(hit): return hit.prop == Air.PLANE and hit.side == "top"), "the opening plane can be stomped from above")
	check(ascent.aircraft.any(func(hit): return hit.prop == Air.HELICOPTER and hit.side == "top"), "the civilian helicopter uses the same roof rule")
	check(ascent.civilians.count(Air.PLANE) == 4 and ascent.civilians.count(Air.HELICOPTER) == 2,
		"all six passengers complete a capture animation and convert once")
	check(ascent.shots_fired > 0 and ascent.shots_dodged > 0 and ascent.shots_hit == 0,
		"the locked military shot can be dodged with a timed tap")
	var under = await play_route("por_baixo", [1.9, 5.85, 6.8, 10.03], recording, true, Vector2(9.65, 12.30))
	check(under.aircraft.any(func(hit): return hit.prop == Air.PLANE and hit.side == "under") and under.civilians.count(Air.PLANE) == 0,
		"rising into the belly keeps the passenger plane in flight")
	var front = await play_route("de_frente", [1.9, 5.85, 6.8, 9.84], recording, true, Vector2(9.50, 12.80))
	check(front.aircraft.any(func(hit): return hit.prop == Air.PLANE and hit.side == "front" and hit.lost == 1)
		and front.civilians.count(Air.PLANE) == 4, "the frontal run loses one zombie and recruits four passengers")
	inputs[-1] = 19.68
	var hit = await play_route("tiro", inputs, recording, true, Vector2(18.43, 20.90))
	check(hit.shots_fired == 1 and hit.shots_hit == 1 and hit.losses == 1, "a late dodge lets a live bullet knock the horde down and remove one member")
	var storm = await play_route("tempestade", [1.9], false, true)
	check("storm" in storm.contacts and storm.rescued == 0 and storm.rejoined == 0 and storm.peak_m < ascent.peak_m,
		"passing through a recovery ember without tapping still leads back to the road")
	var bat = await play_route("morcego", [2.22], false, true)
	check("bat" in bat.contacts and bat.losses == 1 and bat.peak_m < storm.peak_m, "the opening bat punishes a late tap")
	var report = {"version": str(ProjectSettings.get_setting("application/config/version")), "checks": checks, "failures": failures, "video_frames": frames, "routes": routes}
	var out = FileAccess.open(folder + "/sky.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(report, "  "))
	out.close()
	print("V153_SKY ", JSON.stringify(report))
	game.queue_free()
	game = null
	for i in range(8): await process_frame
	quit(0 if failures.is_empty() else 1)
