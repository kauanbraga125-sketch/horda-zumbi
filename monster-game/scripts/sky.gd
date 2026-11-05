extends RefCounted

const PAD_WIDTH = 250.0
const PAD_HEIGHT = 56.0
const GRAVITY = 680.0
const TERMINAL_FALL = 1180.0
const MAX_CHARGES = 5
const COOLDOWN = 0.18
const PAD_CROSSING_MARGIN = 18.0
const POSES = {
	"ember": Vector2(29, 39), "balloon": Vector2(52, 58), "cloud": Vector2(87, 25),
	"bat": Vector2(61, 39), "storm": Vector2(70, 52),
}
# Seconds ahead of the trampoline, altitude in world pixels, and object type.
const COURSE = [
	[.54, 435.0, "ember"], [1.12, 634.0, "balloon"],
	[1.78, 1040.0, "ember"], [2.58, 1230.0, "bat"], [2.88, 1440.0, "ember"],
	[3.15, 854.0, "ember"], [3.76, 1425.0, "cloud"],
	[4.27, 1770.0, "ember"], [5.16, 1990.0, "storm"],
	[5.68, 1730.0, "ember"], [5.83, 2170.0, "ember"],
	[6.76, 2400.0, "ember"], [7.72, 2680.0, "ember"],
]

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
	var origin = r.world_px + r.ANCHOR
	for entry in COURSE:
		objects.append({"x": origin + entry[0] * r.speed, "height": entry[1], "kind": entry[2], "used_at": -1.0})
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

func object_point(r, e: Dictionary, at: float) -> Vector2:
	var rhythm = float(e.height) * .013
	var amplitude = 11.0 if e.kind == "bat" else 5.0
	var y = r.FLOOR - float(e.height) + (19.0 if e.kind == "cloud" else -46.0)
	return Vector2(float(e.x) - r.world_px, y + sin(at * 3.7 + rhythm) * amplitude)

func touch_object(r, e: Dictionary, point: Vector2) -> void:
	e.used_at = age
	var effect = {"x": point.x, "y": point.y, "prop": e.kind}
	match e.kind:
		"ember":
			charges += 1
			notice = "+1 CARGA"
			effect.type = "sky_charge"
			r.events.append(effect)
		"balloon", "cloud":
			notice = "IMPULSO GRÁTIS"
			boost(r, 790.0 if e.kind == "balloon" else 870.0)
			effect.type = "sky_bounce"
			r.events.append(effect)
		"bat", "storm":
			velocity = -530.0 if e.kind == "bat" else -690.0
			hurt_left = .48
			boost_left = 0.0
			notice = "PERDEU ALTURA"
			effect.type = "sky_hit"
			r.events.append(effect)
	notice_left = .95

func advance(r, dt: float) -> void:
	age += dt
	cooldown = maxf(0.0, cooldown - dt)
	boost_left = maxf(0.0, boost_left - dt)
	hurt_left = maxf(0.0, hurt_left - dt)
	notice_left = maxf(0.0, notice_left - dt)
	var travel = r.speed * dt
	r.world_px += travel
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
	for m in r.members:
		if m.falling:
			m.y += maxf(300.0, float(m.vy)) * dt
			m.x -= travel
			continue
		var id = int(m.id)
		var rank = int(m.formation_rank)
		var target = sin(float(rank) * 1.8 - age * 2.3) * minf(float(rank) * 4.0, 20.0)
		var offset = lerpf(float(spacing.get(id, 0.0)), target, 1.0 - exp(-dt * 8.0))
		spacing[id] = offset
		var landing = smoothstep(0.0, 105.0, altitude) if velocity < 0.0 else 1.0
		m.y = r.FLOOR - maxf(0.0, altitude + offset * landing)
		m.vy = -velocity
		m.air_time += dt
	r.mission_stats.space_altitude = maxi(int(r.mission_stats.get("space_altitude", 0)), int(peak / 30.0))
	r.mission_stats.space_distance = maxi(int(r.mission_stats.get("space_distance", 0)), int((r.world_px - start_world) / 30.0))
	if altitude <= 0.0:
		finish(r)
		return
	for e in objects:
		if e.used_at >= 0 or (e.kind == "ember" and charges == MAX_CHARGES) or (e.kind in ["bat", "storm"] and hurt_left > 0.0):
			continue
		var point = object_point(r, e, age)
		var radius: Vector2 = POSES[e.kind]
		if point.x > r.ANCHOR + radius.x + travel + 38.0 or point.x < r.view_left - radius.x:
			continue
		for m in r.members:
			if m.falling: continue
			var y = float(m.y) - (0.0 if e.kind == "cloud" else 46.0)
			var dx = clampf(float(m.x) - point.x, 0.0, travel)
			var delta = (Vector2(float(m.x) - dx, y) - point) / (radius + Vector2(15.0, 17.0))
			if delta.length_squared() <= 1.0:
				touch_object(r, e, point)
				break

func finish(r) -> void:
	active = false
	objects.clear()
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
	r.events.append({"type": "sky_land", "peak": int(peak / 30.0)})
