extends RefCounted

const PAD_WIDTH = 250.0
const PAD_HEIGHT = 56.0
const GRAVITY = 680.0
const TERMINAL_FALL = 1180.0
const MAX_CHARGES = 5
const COOLDOWN = 0.18
const PAD_CROSSING_MARGIN = 18.0
const POSES = {
	"ember": Vector2(30, 39), "balloon": Vector2(49, 54), "cloud": Vector2(87, 25),
	"bat": Vector2(43, 29), "storm": Vector2(68, 36),
}
const Course = preload("res://scripts/sky_course.gd")
var course = Course.new()
var visual = preload("res://scripts/sky_visual.gd").new()
var pending = false
var active = false
var pad_world = 0.0
var age = 0.0
var altitude = 0.0
var velocity = 0.0
var peak = 0.0
var charges = 0
var cooldown = 0.0
var hurt_left = 0.0
var boost_left = 0.0
var start_world = 0.0
var street_ready = false
var notice = ""
var notice_left = 0.0
var objects: Array[Dictionary] = []
var bursts: Array[Dictionary] = []
var landing: Dictionary = {}
var reform_left = 0.0
var spacing: Dictionary = {}

func reset() -> void:
	pending = false
	active = false
	pad_world = 0.0
	age = 0.0
	peak = 0.0
	altitude = 0.0
	velocity = 0.0
	charges = 0
	notice_left = 0.0
	objects.clear()
	bursts.clear()
	landing.clear()
	reform_left = 0.0
	spacing.clear()

func offer(r, forced: bool) -> bool:
	if pending or active or r.sewer.encounter.pending or r.sewer.active or r.space.active or r.dead or r.inside_tunnel():
		return false
	var distance = clampf(r.speed * 1.9, 560.0, 1000.0)
	var centre = r.ANCHOR + distance
	var absolute = r.world_px + centre
	if not forced:
		if not r.safe_world_position(absolute + PAD_WIDTH) or not r.moving_lane_safe(centre, 220.0):
			return false
		if r.ground_y(centre) != r.FLOOR:
			return false
	pending = true
	pad_world = absolute
	visual.warm()
	return true

func contact(r, member: Dictionary, old_foot: Vector2, step: float) -> bool:
	if not pending or member.falling or float(member.vy) <= 0 or r.transform_left > 0 or r.perk_left > 0:
		return false
	var top = r.FLOOR - PAD_HEIGHT
	if old_foot.y > top or float(member.y) < top:
		return false
	var fraction = inverse_lerp(old_foot.y, float(member.y), top)
	var crossing = r.world_px - step + lerpf(old_foot.x, float(member.x) + step, fraction)
	return absf(crossing - pad_world) <= PAD_WIDTH * 0.5 - PAD_CROSSING_MARGIN

func pass_launcher(r) -> void:
	if pending and pad_world + PAD_WIDTH * .5 < r.world_px + r.view_left - 24.0:
		pending = false
		r.sewer.encounter.skip(r)

func begin(r, member: Dictionary) -> void:
	pending = false
	active = true
	age = 0.0
	altitude = r.FLOOR - float(member.y)
	peak = altitude
	velocity = 880.0
	charges = 2
	cooldown = .23
	hurt_left = 0.0
	boost_left = .35
	street_ready = false
	start_world = r.world_px
	notice_left = 0.0
	spacing.clear()
	objects.clear()
	bursts.clear()
	landing.clear()
	reform_left = 0.0
	for e in r.entities:
		if e.kind in ["civilian", "police", "soldier"] and e.state == "capture":
			r.complete_capture(e)
	for m in r.members:
		if not m.falling: spacing[int(m.id)] = r.FLOOR - float(m.y) - altitude
		m.jump_queue.clear()
		m.jump_at = -1.0
		m.jump_delay = -1.0
	r.jump_buffer_until = -1.0
	r.wave_holds.clear()
	r.wave_durations.clear()
	r.wave_started.clear()
	course.start(r, self)
	r.flights += 1
	r.mission_stats.space_flights = int(r.mission_stats.get("space_flights", 0)) + 1
	r.events.append({"type": "sky_launch", "x": pad_world - r.world_px, "y": r.FLOOR - PAD_HEIGHT})

func impulse(r) -> void:
	if charges <= 0 or cooldown > 0.0 or hurt_left > .19:
		return
	charges -= 1
	boost(r, 850.0)

func boost(r, speed: float) -> void:
	velocity = maxf(velocity, speed)
	cooldown = COOLDOWN
	boost_left = .32
	r.events.append({"type": "sky_boost", "y": r.FLOOR - altitude - 16})

func add_object(kind: String, x: float, height: float) -> void:
	var pressure = Course.pressure(height)
	objects.append({"kind": kind, "x": x, "height": height, "used_at": -1.0,
		"alert_at": -1.0, "warning": lerpf(.44, .29, pressure) if kind == "bat" else lerpf(.68, .49, pressure),
		"attack": .52 if kind == "bat" else .23, "dive_y": 0.0, "pressure": pressure})

func hazard_phase(e: Dictionary) -> String:
	if e.alert_at < 0.0: return "idle"
	var since = age - float(e.alert_at)
	if since < float(e.warning): return "warn"
	if since < float(e.warning) + float(e.attack): return "attack"
	return "recover"

func strike_length(e: Dictionary) -> float:
	return lerpf(128.0, 164.0, e.pressure)

func object_point(r, e: Dictionary, at: float) -> Vector2:
	var rhythm = float(e.height) * .013
	var amplitude = 11.0 if e.kind == "bat" else 5.0
	var y = r.FLOOR - float(e.height) + (19.0 if e.kind == "cloud" else -46.0)
	var point = Vector2(float(e.x) - r.world_px, y + sin(at * 3.7 + rhythm) * amplitude)
	if e.kind == "bat" and e.alert_at >= 0.0:
		var attack_age = at - float(e.alert_at) - float(e.warning)
		var dive = clampf(attack_age, 0.0, float(e.attack))
		point.x -= dive * lerpf(240.0, 375.0, e.pressure) + maxf(0.0, attack_age - float(e.attack)) * 45.0
		point.y += float(e.dive_y) * smoothstep(-.12, float(e.attack) * .66, attack_age)
	return point

func alert_hazard(r, e: Dictionary, point: Vector2, lead: Dictionary) -> void:
	if e.alert_at >= 0.0 or lead.is_empty(): return
	var dx = point.x - float(lead.x)
	var dy = float(lead.y) - 46.0 - point.y
	var range_y = 255.0 if e.kind == "bat" else 360.0
	var lead_time = 1.07 if e.kind == "bat" else lerpf(1.06, .77, e.pressure)
	if dx < 32.0 or dx > r.speed * lead_time + 40.0 or absf(dy) > range_y: return
	e.alert_at = age
	if e.kind == "storm":
		e.warning = maxf(float(e.warning), dx / r.speed - .16)
	e.dive_y = clampf(dy * .60, -105.0, 110.0)
	r.events.append({"type": "sky_warn", "prop": e.kind, "x": point.x, "y": point.y})

func emit_burst(r, kind: String, point: Vector2, extra: Dictionary = {}) -> void:
	if bursts.size() >= 24: bursts.pop_front()
	var data = {"kind": kind, "x": r.world_px + point.x, "y": point.y, "at": age}
	data.merge(extra)
	bursts.append(data)

func touch_object(r, e: Dictionary, point: Vector2, member_index: int) -> void:
	e.used_at = age
	var effect = {"x": point.x, "y": point.y, "prop": e.kind}
	match e.kind:
		"ember":
			charges += 1
			emit_burst(r, "ember", point)
			notice = "+1 BRASA"
			effect.type = "sky_charge"
		"balloon", "cloud":
			emit_burst(r, e.kind, point)
			notice = "CAVEIRA ESTOUROU" if e.kind == "balloon" else "SALTO FANTASMA"
			boost(r, 790.0 if e.kind == "balloon" else 870.0)
			effect.type = "sky_bounce"
		"bat", "storm":
			var knock = -530.0 if e.kind == "bat" else -690.0
			velocity = maxf(-TERMINAL_FALL, minf(knock, velocity - 145.0))
			hurt_left = .68
			boost_left = 0.0
			notice = "PERDEU ALTURA"
			effect.type = "sky_hit"
			if e.kind == "bat" and r.active_count() > 1:
				var member: Dictionary = r.members[member_index]
				var previous: int = r.active_count()
				var kind = int(member.kind)
				var wear: Array = r.cosmetics_for(member, kind).duplicate()
				var foot = Vector2(member.x, member.y)
				r.damage(member_index, "sky_bat")
				if r.active_count() < previous:
					notice = "MORCEGO • −1 HORDA"
					effect.lost = 1
					emit_burst(r, "casualty", foot, {"member_kind": kind, "wear": wear})
					r.refresh_formation()
					reform_left = 1.1
	r.events.append(effect)
	notice_left = 1.12

func update_contacts(r, travel: float) -> void:
	var lead_index: int = r.leader_index()
	var lead: Dictionary = r.members[lead_index] if lead_index >= 0 else {}
	for e in objects:
		var kind: String = e.kind
		if e.used_at >= 0.0 or (kind == "ember" and charges == MAX_CHARGES): continue
		var point = object_point(r, e, age)
		var hazard = kind in ["bat", "storm"]
		if hazard:
			alert_hazard(r, e, point, lead)
			if hurt_left > 0.0: continue
		var radius: Vector2 = POSES[kind]
		if point.x > r.ANCHOR + radius.x + travel + 38.0 or point.x < r.view_left - radius.x: continue
		var striking = kind == "storm" and hazard_phase(e) == "attack"
		if kind == "storm" and not striking: continue
		for i in range(r.members.size()):
			var m: Dictionary = r.members[i]
			if m.falling: continue
			var y = float(m.y) - (0.0 if kind == "cloud" else 46.0)
			var dx = clampf(float(m.x) - point.x, 0.0, travel)
			var diff = Vector2(float(m.x) - dx, y) - point
			var delta = diff / (radius + Vector2(15.0, 17.0))
			var bolt = striking and absf(diff.x) < 32.0 and diff.y >= -7.0 and diff.y <= strike_length(e) + 24.0
			if bolt or (kind != "storm" and delta.length_squared() <= 1.0):
				touch_object(r, e, point, i)
				break

func advance(r, dt: float) -> void:
	age += dt
	cooldown = maxf(0.0, cooldown - dt)
	boost_left = maxf(0.0, boost_left - dt)
	hurt_left = maxf(0.0, hurt_left - dt)
	notice_left = maxf(0.0, notice_left - dt)
	reform_left = maxf(0.0, reform_left - dt)
	r.hit_grace = maxf(0.0, r.hit_grace - dt)
	var travel = r.speed * dt
	r.world_px += travel
	course.fill(r, self)
	for i in range(objects.size() - 1, -1, -1):
		if object_point(r, objects[i], age).x < r.view_left - 230.0: objects.remove_at(i)
	while not bursts.is_empty() and age - float(bursts[0].at) > .85: bursts.pop_front()
	for e in r.entities: e.x -= travel
	for tunnel in r.tunnels:
		if not tunnel.entered: tunnel.entry += travel
	velocity = maxf(-TERMINAL_FALL, velocity - GRAVITY * dt)
	altitude = maxf(0.0, altitude + velocity * dt)
	peak = maxf(peak, altitude)
	if not street_ready and altitude > 515.0:
		# The road is below the camera here. Build the landing stretch while it is hidden.
		for e in r.entities:
			if e.kind == "coin" and not e.taken: r.miss_coin_row(e)
		r.entities.clear()
		r.sewer.reserve_ground(r, r.world_px + r.generation_horizon() + 9500.0)
		street_ready = true
	elif street_ready and r.world_px + r.generation_horizon() + 1000.0 > r.terrain.generated_to:
		r.sewer.reserve_ground(r, r.world_px + r.generation_horizon() + 9500.0)
	for i in range(r.members.size()):
		var m: Dictionary = r.members[i]
		if m.falling:
			m.y += maxf(300.0, float(m.vy)) * dt
			m.x -= travel
			continue
		var id = int(m.id)
		var rank = int(m.formation_rank)
		var target = sin(float(rank) * 1.8 - age * 2.3) * minf(float(rank) * 4.0, 20.0)
		var offset = lerpf(float(spacing.get(id, 0.0)), target, 1.0 - exp(-dt * 8.0))
		spacing[id] = offset
		var landing_blend = smoothstep(0.0, 105.0, altitude) if velocity < 0.0 else 1.0
		m.y = r.FLOOR - maxf(0.0, altitude + offset * landing_blend)
		if reform_left > 0.0: m.x = move_toward(float(m.x), r.slot_x(i), dt * 185.0)
		m.vy = -velocity
		m.air_time += dt
	r.mission_stats.space_altitude = maxi(int(r.mission_stats.get("space_altitude", 0)), int(peak / 30.0))
	r.mission_stats.space_distance = maxi(int(r.mission_stats.get("space_distance", 0)), int((r.world_px - start_world) / 30.0))
	if altitude <= 0.0:
		finish(r)
		return
	update_contacts(r, travel)

func finish(r) -> void:
	active = false
	objects.clear()
	bursts.clear()
	var lead_index: int = r.leader_index()
	var lead_x = float(r.members[lead_index].x) if lead_index >= 0 else float(r.ANCHOR)
	landing = {"at": r.elapsed, "x": r.world_px + lead_x, "force": clampf(absf(velocity) / TERMINAL_FALL, .46, 1.0)}
	r.sewer.encounter.complete(r, "space")
	r.next_pattern_world = maxf(r.next_pattern_world, r.world_px + r.generation_horizon() + 130.0)
	for m in r.members:
		if m.falling: continue
		m.y = r.ground_y(m.x)
		m.surface_y = m.y
		m.vy = 0.0
		m.air_time = 0.0
		m.air_pose = 0.0
		m.air_jumps = 0
		m.roof_id = -1
		m.land_left = .20
	r.events.append({"type": "sky_land", "peak": int(peak / 30.0), "force": landing.force})
