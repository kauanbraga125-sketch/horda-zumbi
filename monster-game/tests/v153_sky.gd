extends "res://tests/v147_reveal.gd"

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

func play_route(label: String, taps: Array, capture: bool, restart: bool = false) -> Dictionary:
	if restart: game.perform_action("lab_sky_restart")
	else: game.start_lab("sky", 6, 0)
	var r = game.runner
	var s = r.sky
	var ids = r.members.map(func(m): return m.id)
	for i in range(r.members.size()):
		r.members[i]["cosmetics_0"] = ["z_plumber"] if i == 0 else []
		r.members[i]["cosmetics_1"] = ["s_ice"] if i == 1 else []
	var height_per_frame = 0.0
	var launch_count = 0
	var landing_tick = -1
	var taps_sent = 0
	var spent = 0
	var started = false
	var velocity_before_hit = 0.0
	var touched: Array[String] = []
	var timestamps: Array[Dictionary] = []
	var previous_foot = Vector2.ZERO
	var named_frames = [0.35, 1.19, 2.43, 3.82, 5.04, 7.5]
	var next_sample = 0
	var launch_pressed = false
	for tick in range(1200):
		if not launch_pressed and s.pad_world - r.world_px - r.ANCHOR < 195.0:
			tap()
			launch_pressed = true
		if s.active and taps_sent < taps.size() and s.age >= float(taps[taps_sent]):
			var before: int = s.charges
			tap()
			spent += before - s.charges
			taps_sent += 1
		velocity_before_hit = s.velocity
		r.advance(STEP, game.jump_held)
		for e in r.events:
			if e.type == "sky_launch":
				launch_count += 1
				check(launch_pressed and s.charges == 2 and s.altitude < 65.0, label + ": actual tap hits the pad and starts the climb at the street")
			if e.type == "sky_land":
				landing_tick = tick
			if e.type in ["sky_charge", "sky_bounce", "sky_hit"]:
				touched.append(e.prop)
			if e.type == "sky_hit":
				check(velocity_before_hit > -530.0 and s.velocity < -500.0, label + ": collision applies a real downward impulse")
			if str(e.type).begins_with("sky_"):
				timestamps.append({"event": e.type, "prop": e.get("prop", ""), "video_frame": frames, "altitude": s.altitude, "charges": s.charges})
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
		if capture and tick % 2 == 0:
			var frame = await picture(false)
			assert(frame.save_jpg(folder + "/frame-%04d.jpg" % frames, .92) == OK)
			frames += 1
		elif not recording and s.active and next_sample < named_frames.size() and s.age >= float(named_frames[next_sample]):
			var still = await picture(false)
			assert(still.save_jpg(folder + "/%s-%02d.jpg" % [label, next_sample], .94) == OK)
			next_sample += 1
		if landing_tick >= 0 and tick > landing_tick + 74:
			break
		if not started and not s.pending: break
	check(launch_count == 1 and landing_tick >= 0 and not s.active, label + ": one takeoff and a natural landing")
	check(r.members.map(func(m): return m.id) == ids and not r.dead, label + ": the same horde runs on after landing")
	check(r.members.all(func(m): return absf(float(m.y) - r.ground_y(float(m.x))) < .5), label + ": members settle on the real street floor")
	check(r.sewer.encounter.completed_count == 1 and r.world_px > s.start_world + 500.0, label + ": the run advances through the handoff")
	check(height_per_frame < 35.0, label + ": camera never jumps between street and sky")
	var report = {"route": label, "peak_m": int(s.peak / 30.0), "taps_used": spent, "contacts": touched, "events": timestamps, "camera_delta_px": height_per_frame}
	routes.append(report)
	return report

func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR")
	assert(not folder.is_empty())
	recording = OS.get_environment("HORDA_SKY_RECORD") == "1"
	DirAccess.make_dir_recursive_absolute(folder)
	skip_test()
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
	game.data.active_cosmetics = ["z_plumber", "s_ice"]
	var ascent = await play_route("subida", [1.9, 4.60, 6.6, 7.95], recording)
	check(ascent.peak_m >= 96 and ascent.taps_used == 4, "timed taps drive a sustained climb")
	check("ember" in ascent.contacts and "balloon" in ascent.contacts and "cloud" in ascent.contacts, "the charge and both free boosts are reachable")
	check(not "bat" in ascent.contacts and not "storm" in ascent.contacts, "both hazards can be dodged using height")
	var bat = await play_route("morcego", [2.22], recording, true)
	check("bat" in bat.contacts and bat.peak_m < ascent.peak_m, "the bat route loses height and returns early")
	var storm = await play_route("tempestade", [1.9], false, true)
	check("storm" in storm.contacts, "the storm route reaches the second downward hazard")
	var report = {"version": "0.10.53", "checks": checks, "failures": failures, "video_frames": frames, "routes": routes}
	var out = FileAccess.open(folder + "/sky.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(report, "  "))
	out.close()
	print("V153_SKY ", JSON.stringify(report))
	game.queue_free()
	game = null
	for i in range(8): await process_frame
	quit(0 if failures.is_empty() else 1)
