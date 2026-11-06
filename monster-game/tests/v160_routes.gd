extends SceneTree

const Events = preload("res://scripts/sewer_event.gd")
const Hauntings = preload("res://scripts/sky_hauntings.gd")
const STEP = 1.0 / 60.0
var checks = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func road(seed_value: int = 160) -> HordeRun:
	var r = HordeRun.new()
	r.start_developer("gap", 6, 0, seed_value)
	r.developer_kind = ""
	r.tutorial_enabled = false
	r.power_owned.clear()
	r.next_segment = 99999
	r.world_px = 4200.0
	r.elapsed = 80.0
	r.ensure_tunnels(r.world_px + 45000.0)
	return r

func advance_to_offer(r, choice: String) -> void:
	var e = r.sewer.encounter
	var original = r.terrain.segments.duplicate(true)
	var obstacle = r.add_entity("crate", r.ANCHOR + 2500.0, r.FLOOR)
	check(e.offer(r, false, choice), "the clear street offers " + choice)
	check(r.entities.has(obstacle) and r.terrain.segments == original, "showing a choice preserves the street")

func choose_branch_test() -> void:
	var r = road()
	advance_to_offer(r, "both")
	var e = r.sewer.encounter
	check(e.pending and r.sky.pending and not e.cutout_pending(), "both entrances are optional")
	for i in range(600):
		r.advance(STEP)
		if not e.pending and not r.sky.pending: break
	check(not e.pending and not r.sky.pending and not r.sky.active and not r.sewer.active,
		"ignoring both entrances continues the street")
	check(e.completed_count == 0 and e.next_at >= r.elapsed + Events.NEXT_WINDOW.x - STEP,
		"skipping the fork schedules a fresh rare window")

	r = road()
	advance_to_offer(r, "both")
	e = r.sewer.encounter
	check(e.select_sewer(r) and not r.sky.pending and e.cutout_pending(), "selecting the sewer closes the trampoline route")
	for i in range(350):
		r.advance(STEP)
		if r.sewer.active: break
	check(r.sewer.active and not r.sky.active, "the chosen sewer actually starts at its dock")

	r = road()
	advance_to_offer(r, "both")
	e = r.sewer.encounter
	var tapped = false
	for i in range(550):
		if not tapped and r.sky.pad_world - r.world_px - r.ANCHOR < 195.0:
			r.jump()
			r.release_jump()
			tapped = true
		r.advance(STEP)
		if r.sky.active: break
	check(r.sky.active and not e.pending and not r.sewer.active, "jumping onto the trampoline closes the sewer choice")

func tunnel_test(kind: String) -> void:
	var r = road()
	var t: Dictionary = r.tunnels[0]
	var entry = float(t.entry)
	r.world_px = entry - 230.0
	r.events.clear()
	if kind == "sewer": r.sewer.begin(r, true)
	else: r.sky.begin(r, r.members[0])
	var before = r.world_px
	for i in range(180):
		r.advance(STEP)
		if r.world_px >= entry + 120.0: break
	check(r.world_px > before and is_equal_approx(t.entry, entry), kind + ": progress never moves the tunnel")
	check(r.inside_tunnel() and r.tunnel_number() == 1 and r.completed_tunnels == 0,
		kind + ": the same road coordinate enters tunnel one")
	var landing = r.world_px
	if kind == "sewer": r.sewer.finish(r)
	else: r.sky.finish(r)
	check(is_equal_approx(r.world_px, landing) and r.inside_tunnel() and r.tunnel_number() == 1,
		kind + ": the horde lands inside the equivalent tunnel")
	check(r.events.any(func(e): return e.type == ("sewer_land" if kind == "sewer" else "sky_land") and e.to_tunnel == 1),
		kind + ": the landing event reports the actual tunnel")
	var next_entry = float(r.tunnels[1].entry)
	r.world_px = entry + float(t.length) + 12.0
	r.update_tunnels()
	check(r.completed_tunnels == 1 and r.area() == t.to and r.tunnels[1].entry == next_entry,
		kind + ": the next ground region begins at its original boundary")

func decor_test() -> void:
	var scenes = {}
	for seed_value in range(18):
		var scene = Hauntings.new()
		scene.reset(seed_value)
		scene.advance(8.0, Hauntings.ORBIT_MIN - 40.0)
		check(scene.clock == 0.0, "the distant spectacle waits for deep space")
		scene.advance(2.0, Hauntings.ORBIT_MIN + 60.0)
		scenes[scene.scene] = true
		var first = scene.scene_at
		scene.advance(12.0, Hauntings.ORBIT_MIN + 60.0)
		check(scene.scene_at == first, "only one far event is scheduled in a short passage")
	check(scenes.size() == 2, "different flights see the bite or the duel")

func run() -> void:
	var chances = {"": 0, "space": 0, "sewer": 0, "both": 0}
	for i in range(1000):
		var kind = Events.roll_kind((float(i) + .5) / 1000.0)
		chances[kind] += 1
	check(chances == {"": 630, "space": 160, "sewer": 160, "both": 50}, "rolls include no detour, either route, or both")
	choose_branch_test()
	tunnel_test("sewer")
	tunnel_test("space")
	decor_test()
	print("V160_ROUTES ", JSON.stringify({"checks": checks, "failures": failures, "rolls": chances}))
	quit(0 if failures.is_empty() else 1)
