extends SceneTree

const Tardis = preload("res://scripts/sky_tardis.gd")
const Orbit = preload("res://scripts/sky_cosmic_vista.gd")
const STEP = 1.0 / 60.0
const ASCENT_TAPS = [1.90, 5.85, 6.80, 8.18, 13.33, 16.20, 17.85, 19.12, 21.55, 23.42, 25.78, 28.42,
	32.195, 32.516, 32.820, 32.904, 33.518, 34.719, 34.941, 35.140, 37.111]
var checks = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func flight(count: int, y_offset: float = 0.0) -> Dictionary:
	var r = HordeRun.new()
	r.start_developer("sky", count, 0, 5330)
	var s = r.sky
	s.begin(r, r.members[0])
	s.objects.clear()
	var course = s.course
	course.next_height = Tardis.MIN_HEIGHT + 200.0
	course.next_x = r.world_px + r.ANCHOR - r.speed * 1.0
	course.place_orbit_leg(s)
	var target: Dictionary = s.objects.back()
	check(target.kind == Tardis.KIND, "deep orbit generates a TARDIS")
	var cabin = s.object_point(r, target, s.age)
	s.altitude = r.FLOOR - cabin.y - 53.0 + y_offset
	s.velocity = 165.0
	s.peak = s.altitude
	s.objects.assign([target])
	r.events.clear()
	return {"runner": r, "target": target}

func ticks(r, count: int) -> void:
	for i in range(count):
		r.advance(STEP)

func events(r, kind: String) -> Array:
	return r.events.filter(func(event): return event.type == kind)

func natural_ascent() -> void:
	var r = HordeRun.new()
	r.start_developer("sky", 6, 0, 5330)
	r.view_right = 1280.0
	for i in range(r.members.size()): r.members[i].kind = i % 2
	check(r.sewer.encounter.offer(r, true, "space"), "the normal journey offers the trampoline")
	var s = r.sky
	var jumped = false
	var next_tap = 0
	for tick in range(4000):
		if not jumped and s.pending and s.pad_world - r.world_px - r.ANCHOR < 195.0:
			jumped = true
			r.jump()
			r.release_jump()
		if s.active and next_tap < ASCENT_TAPS.size() and s.age >= ASCENT_TAPS[next_tap]:
			next_tap += 1
			r.jump()
			r.release_jump()
		r.advance(STEP)
		if jumped and not s.pending and not s.active: break
	check(events(r, "sky_launch").size() == 1 and s.peak >= Orbit.SPACE_FULL,
		"timed jumps from the street reach the deep-space layer")
	check(events(r, "sky_tardis_grab").size() == 1 and s.tardis.converted == 3,
		"the generated course allows the player to capture all three travelers")
	check(events(r, "sky_land").size() == 1 and r.active_count() == 6 + r.recruits - r.losses,
		"the horde returns to the street with the earned recruits")

func run() -> void:
	check(Orbit.space_blend(Tardis.MIN_HEIGHT - 1200.0) == 0.0 and Orbit.space_blend(11000.0) == 1.0,
		"deep space fades in from the atmosphere")
	var missed = flight(6, -550.0)
	ticks(missed.runner, 175)
	check(missed.target.used_at < 0.0 and missed.runner.souls == 0, "an off-course TARDIS does not capture at a distance")

	var fixture = flight(6)
	var r: HordeRun = fixture.runner
	var s = r.sky
	for i in range(8):
		s.course.place_orbit_leg(s)
	check(s.objects.filter(func(obj): return obj.kind == Tardis.KIND).size() == 1,
		"only one TARDIS is offered in a climb")
	ticks(r, 26)
	check(events(r, "sky_tardis_grab").size() == 1 and s.tardis.started_at >= 0.0,
		"flying into the TARDIS triggers the animation once")
	check(r.souls == 0 and s.tardis.released == 0, "the first loop plays before recruitment")
	ticks(r, 60)
	check(events(r, "sky_tardis_phase").map(func(event): return event.phase) == ["rewind", "repeat", "rewind", "open"],
		"the box breaks, rewinds twice and opens")
	check(r.souls == 0, "opening the box does not bypass the capture animation")
	ticks(r, 100)
	check(events(r, "sky_tardis_release").map(func(event): return event.traveler) == Tardis.TRAVELERS,
		"the Doctor, Amy and Rory emerge in order")
	check(r.souls == 3 and r.active_count() == 9 and s.tardis.converted == 3,
		"each traveler becomes exactly one soul and one recruit")
	check(events(r, "sky_civil").filter(func(event): return event.prop == Tardis.KIND).size() == 3,
		"all three complete the standard aerial capture")
	check(s.captures.active.is_empty(), "all capture tracks finish")

	var early = flight(1).runner
	ticks(early, 26)
	check(early.sky.tardis.started_at >= 0.0 and early.souls == 0, "the single survivor also reaches the cabin")
	early.sky.altitude = .02
	early.sky.velocity = -200.0
	ticks(early, 1)
	check(not early.sky.active and early.souls == 3 and early.active_count() == 4,
		"landing during the loop settles all earned travelers")
	early.sky.tardis.settle(early, early.sky)
	early.sky.captures.settle(early, early.sky)
	check(early.souls == 3, "settling a finished sequence is idempotent")
	early.sky.reset()
	check(early.sky.tardis.started_at < 0.0 and early.sky.tardis.released == 0,
		"reset clears the loop before a new climb")
	natural_ascent()
	print("V159_TARDIS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
