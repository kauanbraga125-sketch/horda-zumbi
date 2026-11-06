extends RefCounted

const PERSON_HEIGHT = 96.0
const Tardis = preload("res://scripts/sky_tardis.gd")
const FLY_POSES = {
	"para_ochre": "para_ochre", "para_lilac": "para_lilac", "jetpack": "jetpack",
	"astronaut": "astro", "orbit_satellite": "navigator", "orbit_shuttle": "alien",
}

var active: Array[Dictionary] = []

func clear() -> void:
	active.clear()

func add(r, centre: Vector2, member_id: int, prop: String, variant: int = -1, delay: float = 0.0, sprite: String = "") -> void:
	var foot = centre + Vector2(0.0, PERSON_HEIGHT * .5)
	var passenger = variant >= 0
	var person = {
		"id": r.next_entity_id, "kind": "civilian", "variant": variant, "state": "normal",
		"taken": false, "rescued": passenger, "from_vehicle": passenger, "group": -1,
		"x": foot.x, "y": foot.y, "origin": foot + Vector2(r.world_px, 0.0),
		"delay": delay, "prop": prop, "capturer": member_id, "sprite": sprite,
	}
	r.next_entity_id += 1
	active.append(person)
	if delay <= 0.0: grip(r, person)

func choose_member(r, person: Dictionary) -> Dictionary:
	var preferred: Dictionary = r.member_by_id(int(person.capturer))
	if not preferred.is_empty() and preferred.attack_left <= 0.0: return preferred
	var best: Dictionary = {}
	var cost = INF
	for m in r.members:
		if m.falling: continue
		var next_cost = absf(float(m.x) - float(person.x)) + float(m.attack_left) * 500.0
		if next_cost < cost:
			best = m
			cost = next_cost
	return best

func grip(r, person: Dictionary) -> void:
	var member = choose_member(r, person)
	if member.is_empty(): return
	r.begin_capture(person, member)
	if person.from_vehicle and person.sprite.is_empty():
		match int(person.variant):
			0:
				person.civil_key = "civil_casaco_azul_nerd"
				person.civil_flip = true
				person.civil_turn_left = 0.0
			1:
				person.woman_clip = "capture"
				person.woman_reverse = true
			2:
				person.worker_time = 0.0
		person.vx = 0.0

func advance(r, sky, dt: float) -> void:
	if active.is_empty(): return
	var completed = false
	for person in active:
		if person.state == "normal":
			person.delay -= dt
			var waiting: Vector2 = person.origin - Vector2(r.world_px, 0.0)
			person.x = waiting.x
			person.y = waiting.y
			if person.delay <= 0.0: grip(r, person)
			continue
		var member: Dictionary = r.member_by_id(int(person.capturer))
		if member.is_empty():
			member = choose_member(r, person)
			if member.is_empty(): continue
			person.capturer = member.id
			member.attack_duration = person.capture_duration
			member.attack_kind = member.kind
			member.attack_left = person.capture_left
		person.capture_left = maxf(0.0, float(person.capture_left) - dt)
		var u = HordeCaptureMotion.progress(person)
		var origin: Vector2 = person.origin - Vector2(r.world_px, 0.0)
		var target = Vector2(member.x, member.y) + person.capture_offset
		# Pull the passenger out of the cabin and into the same grip used on the street.
		var foot = origin.lerp(target, smoothstep(0.0, .46, u))
		if person.from_vehicle:
			var tumble = sin(PI * smoothstep(.0, .53, u))
			foot += Vector2((int(person.variant) - 1) * 15.0, -36.0) * tumble
		person.x = foot.x
		person.y = foot.y
		person.worker_time = float(person.capture_duration) - float(person.capture_left)
		if person.capture_left <= 0.0:
			complete(r, sky, person)
			completed = completed or bool(person.taken)
	if completed: active = active.filter(func(person): return not person.taken)

func complete(r, sky, person: Dictionary) -> void:
	var before: int = r.members.size()
	var foot = Vector2(person.x, person.y)
	r.complete_capture(person, foot)
	if r.members.size() > before:
		var recruit: Dictionary = r.members[-1]
		recruit.sky_arrival = .28
		sky.spacing[int(recruit.id)] = r.FLOOR - float(recruit.y) - sky.altitude
		r.refresh_formation()
		sky.reform_left = 1.1
	if person.taken:
		var centre = foot - Vector2(0, 48)
		sky.emit_burst(r, "conversion", centre)
		r.events.append({"type": "sky_civil", "x": centre.x, "y": centre.y, "prop": person.prop, "passenger": person.from_vehicle})
		if person.prop == Tardis.KIND:
			sky.tardis.confirm_capture(sky)
		elif not person.from_vehicle:
			sky.notice = "+1 ALMA • CIVIL CAPTURADO"
			sky.notice_left = 1.12

func settle(r, sky) -> void:
	for person in active: complete(r, sky, person)
	clear()

func paint(g, motion, member_id: int) -> void:
	for person in active:
		if person.state != "capture" or int(person.capturer) != member_id: continue
		if person.from_vehicle and person.sprite.is_empty():
			g.draw_civilian(person)
			continue
		var u = HordeCaptureMotion.progress(person)
		var foot = Vector2(person.x, person.y)
		var point = foot - Vector2(0, PERSON_HEIGHT * .5) + HordeCaptureMotion.offset(person, PERSON_HEIGHT)
		var tint = HordeCaptureMotion.tint(person)
		tint = tint.lerp(Color(.90, .65, 1.0, tint.a), smoothstep(.65, .98, u))
		var key: String = str(person.prop) + "_panic" if person.sprite.is_empty() else person.sprite
		if key == "orbit_alien_caught" and u < .26: key = "orbit_alien_float"
		var roll = HordeCaptureMotion.angle(person)
		var pose: String = FLY_POSES.get(person.prop, "")
		if not pose.is_empty():
			var progression = HordeCaptureMotion.grip_progress(person)
			if u >= .13 or person.prop == "orbit_satellite":
				key = pose + ("_grab" if progression < .49 else "_struggle")
			var resistance = sin(progression * TAU * 1.8) * (1.0 - progression)
			roll += resistance * .26
			point += Vector2(7.0 * resistance, -sin(progression * PI) * 11.0)
			if person.prop == "orbit_shuttle" and int(person.variant) == 1:
				tint = tint.lerp(Color(.85, .92, 1.0, tint.a), .57)
		motion.sprite(g.paint_target, key, point, 122.0, tint, roll)
