extends RefCounted

const PLANE = "air_plane"
const HELICOPTER = "air_helicopter"
const PATROL = "air_patrol"
const SPECS = {
	PLANE: {"width": 346.0, "hull": Rect2(-137, -34, 241, 81), "speed": 83.0, "seats": [0, 1, 2, 0]},
	HELICOPTER: {"width": 295.0, "hull": Rect2(-103, -61, 161, 148), "speed": 52.0, "seats": [2, 1]},
	PATROL: {"width": 302.0, "hull": Rect2(-103, -58, 195, 112), "speed": 66.0, "seats": []},
}
const HALF_BODY = 23.0
const HEAD_HEIGHT = 99.0
const AIM_TIME = .32
const FIRE_TIME = .92
const TRACER_SPEED = 795.0
const WARNING = Color("ffae77")

var shots: Array[Dictionary] = []

static func is_aircraft(kind: String) -> bool:
	return SPECS.has(kind)

func point(r, sky, craft: Dictionary, age: float) -> Vector2:
	var broken_at = float(craft.used_at)
	if broken_at >= 0.0 and age >= broken_at:
		var t = age - broken_at
		var origin: Vector2 = craft.wreck_origin
		return origin + Vector2(-r.world_px - 114.0 * t, 46.0 * t + 310.0 * t * t)
	var pass_at = (float(craft.x) - sky.start_world - r.ANCHOR) / r.speed
	var t = age - pass_at
	var bob = sin(t * 2.35 + float(craft.height) * .009) * 11.0
	return Vector2(float(craft.x) - r.world_px - t * SPECS[craft.kind].speed, r.FLOOR - float(craft.height) + bob)

# Sweep the feet against the fuselage expanded by the standing body's extent.
# The first surface crossed decides the outcome even at the cabin corners.
static func entry(from: Vector2, to: Vector2, hull: Rect2) -> Dictionary:
	var box = hull.grow_individual(HALF_BODY, 0.0, HALF_BODY, HEAD_HEIGHT)
	var hit: Dictionary = {}
	var delta = to - from
	if delta.y > 0.0 and from.y <= box.position.y and to.y >= box.position.y:
		var t = (box.position.y - from.y) / delta.y
		var x = lerpf(from.x, to.x, t)
		if x >= box.position.x and x <= box.end.x: hit = {"side": "top", "t": t}
	elif delta.y < 0.0 and from.y >= box.end.y and to.y <= box.end.y:
		var t = (box.end.y - from.y) / delta.y
		var x = lerpf(from.x, to.x, t)
		if x >= box.position.x and x <= box.end.x: hit = {"side": "under", "t": t, "correction": box.end.y - to.y + 1.0}
	if delta.x > 0.0 and from.x <= box.position.x and to.x >= box.position.x:
		var t = (box.position.x - from.x) / delta.x
		var y = lerpf(from.y, to.y, t)
		if y > box.position.y and y < box.end.y and (hit.is_empty() or t < float(hit.t)):
			hit = {"side": "front", "t": t}
	return hit

func advance_craft(r, sky, craft: Dictionary, centre: Vector2, old_centre: Vector2, previous_feet: Dictionary, lead: Dictionary) -> void:
	if craft.used_at >= 0.0: return
	if craft.kind == PATROL: aim_and_fire(r, sky, craft, centre, lead)
	if lead.is_empty() or minf(centre.x, old_centre.x) > float(lead.x) + 180.0: return
	var hull: Rect2 = SPECS[craft.kind].hull
	var closest: Dictionary = {}
	var member_index = -1
	for i in range(r.members.size()):
		var m: Dictionary = r.members[i]
		if m.falling: continue
		var foot = Vector2(m.x, m.y)
		var old_foot: Vector2 = previous_feet.get(m.id, foot)
		var hit = entry(old_foot - old_centre, foot - centre, hull)
		if hit.is_empty() or (hit.side == "front" and craft.get("bumped_under", false)): continue
		if closest.is_empty() or hit.t < closest.t:
			closest = hit
			member_index = i
	if member_index < 0: return
	var member: Dictionary = r.members[member_index]
	var side: String = closest.side
	var event = {"type": "sky_aircraft", "x": centre.x, "y": centre.y, "prop": craft.kind, "side": side, "lost": 0, "passengers": 0}
	if craft.kind == PATROL:
		if craft.get("body_hit", false) or sky.hurt_left > 0.0: return
		craft.body_hit = true
		sky.knock_down(r, -255.0)
		event.lost = int(sky.lose_member(r, member_index, "vehicle"))
		sky.notice = "IMPACTO COM A PATRULHA"
	elif side == "under":
		sky.block_rise(r, float(closest.correction), -85.0)
		if craft.get("bumped_under", false): return
		craft.bumped_under = true
		sky.emit_burst(r, "air_scrape", Vector2(member.x, member.y - HEAD_HEIGHT))
		sky.notice = "POR BAIXO • SUBIDA BLOQUEADA"
	else:
		craft.used_at = sky.age
		craft.wreck_origin = centre + Vector2(r.world_px, 0.0)
		craft.wreck_spin = -.72 if side == "top" else 1.07
		if side == "top":
			sky.boost(r, 920.0)
			sky.notice = "POR CIMA • IMPULSO!"
		else:
			sky.knock_down(r, -285.0)
			event.lost = int(sky.lose_member(r, member_index, "vehicle"))
			sky.notice = "BATIDA DE FRENTE • PASSAGEIROS LIBERADOS"
		var seats: Array = SPECS[craft.kind].seats
		var first_window = -40.0 if craft.kind == PLANE else 9.0
		for i in range(seats.size()):
			var seat = centre + Vector2(first_window + i * 30.0, -4.0)
			sky.captures.add(r, seat, int(member.id), craft.kind, int(seats[i]), float(i) * .10)
		event.passengers = seats.size()
		r.cars += 1
		if craft.kind == PLANE:
			r.mission_stats.vehicle_plane = int(r.mission_stats.get("vehicle_plane", 0)) + 1
		sky.emit_burst(r, "air_scrape", centre - Vector2(15, 22))
	sky.notice_left = 1.25
	r.events.append(event)

static func angle(craft: Dictionary, age: float) -> float:
	if craft.used_at >= 0.0:
		var t = age - float(craft.used_at)
		return float(craft.wreck_spin) * (1.0 - exp(-2.3 * t)) + sin(t * 9.0) * .085
	return sin(age * 2.7 + float(craft.height) * .003) * .035

static func muzzle(craft: Dictionary, centre: Vector2, age: float) -> Vector2:
	return centre + Vector2(-155.0, 49.0).rotated(angle(craft, age))

func aim_and_fire(r, sky, craft: Dictionary, centre: Vector2, lead: Dictionary) -> void:
	if lead.is_empty() or craft.has("shot_at"): return
	var gun = muzzle(craft, centre, sky.age)
	var ahead = gun.x - float(lead.x)
	var target_y = float(lead.y) - 52.0
	if craft.alert_at < 0.0:
		if ahead < 540.0 or ahead > 725.0 or absf(target_y - gun.y) > 230.0: return
		craft.alert_at = sky.age
		sky.notice = "PATRULHA MIRANDO"
		sky.notice_left = FIRE_TIME
		r.events.append({"type": "sky_aircraft_warn", "x": gun.x, "y": gun.y})
	var since = sky.age - float(craft.alert_at)
	if not craft.has("target") or since < AIM_TIME:
		craft.target = Vector2(lead.x, target_y)
	var target: Vector2 = craft.target
	var slope = clampf((target.y - gun.y) / maxf(gun.x - target.x, 120.0), -.38, .38)
	craft.aim = Vector2(-1.0, slope).normalized()
	if since < FIRE_TIME: return
	craft.shot_at = sky.age
	if ahead < 95.0: return
	# Match the warning ray's slope after the camera adds the world scroll.
	var velocity = Vector2(-TRACER_SPEED, slope * (TRACER_SPEED + r.speed))
	shots.append({"origin": gun + Vector2(r.world_px, 0.0), "velocity": velocity, "at": sky.age, "spent": false})
	r.events.append({"type": "sky_aircraft_shot", "x": gun.x, "y": gun.y})

static func shot_point(r, shot: Dictionary, age: float) -> Vector2:
	return shot.origin + shot.velocity * maxf(0.0, age - float(shot.at)) - Vector2(r.world_px, 0.0)

func advance_shots(r, sky, dt: float, travel: float, previous_feet: Dictionary) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var shot = shots[i]
		var now = shot_point(r, shot, sky.age)
		if now.x < r.view_left - 100.0:
			shots.remove_at(i)
			continue
		if shot.spent or sky.age <= shot.at: continue
		var before = shot_point(r, shot, sky.age - dt) + Vector2(travel, 0.0)
		var tail = INF
		for j in range(r.members.size()):
			var m: Dictionary = r.members[j]
			if m.falling: continue
			tail = minf(tail, float(m.x))
			if sky.hurt_left > 0.0 or not sky.swept_pickup(m, previous_feet, now, before, Vector2(34.0, 48.0)): continue
			shot.spent = true
			sky.knock_down(r, -305.0)
			var lost = sky.lose_member(r, j, "bullet")
			sky.notice = "ATINGIDO • −1 HORDA" if lost else "ATINGIDO • PERDEU ALTURA"
			sky.notice_left = 1.12
			sky.emit_burst(r, "air_scrape", now)
			r.events.append({"type": "sky_bullet_hit", "prop": PATROL, "x": now.x, "y": now.y, "lost": int(lost)})
			break
		if not shot.spent and now.x < tail - 44.0 and not shot.get("passed", false):
			shot.passed = true
			r.events.append({"type": "sky_aircraft_dodge", "prop": PATROL, "x": now.x, "y": now.y})
			if not sky.recovering and sky.notice_left <= .35:
				sky.notice = "TIRO DESVIADO"
				sky.notice_left = .82

func paint(g, motion, sky, craft: Dictionary, centre: Vector2) -> void:
	var canvas: Node2D = g.paint_target
	var broken = craft.used_at >= 0.0
	var armed = craft.kind == PATROL
	var targeting = armed and craft.alert_at >= 0.0 and not craft.has("shot_at")
	var since_break = sky.age - float(craft.used_at)
	if broken and since_break >= 2.25: return
	var key: String = craft.kind
	if broken: key += "_wreck"
	elif targeting and sky.age - craft.alert_at >= AIM_TIME: key += "_aim"
	var roll = angle(craft, sky.age)
	var width: float = SPECS[craft.kind].width
	var scale = width / float(motion.frames[key].size.x)
	var fade = 1.0 - smoothstep(1.45, 2.25, since_break) if broken else 1.0
	if broken:
		for i in range(4):
			var age = maxf(0.0, since_break - i * .10)
			var smoke = centre + Vector2(22.0 + 96.0 * age + i * 14.0, -26.0 - 66.0 * age - i * 18.0)
			motion.sprite(canvas, "mist_far", smoke, 81.0 + 29.0 * age, Color(.35, .28, .43, fade * .45), -roll * .2)
	motion.sprite(canvas, key, centre, scale, Color(1, 1, 1, fade), roll)
	if broken: return
	match craft.kind:
		PLANE:
			rotor(canvas, centre + Vector2(-109, 35).rotated(roll), 29.0, .22, sky.age * 46.0, roll + PI * .5)
			rotor(canvas, centre + Vector2(-62, 48).rotated(roll), 36.0, .24, sky.age * 52.0, roll + PI * .5)
		HELICOPTER:
			rotor(canvas, centre + Vector2(-8, -111).rotated(roll), 125.0, .074, sky.age * 37.0, roll)
			rotor(canvas, centre + Vector2(158, -18).rotated(roll), 19.0, .82, sky.age * 45.0, roll)
		PATROL:
			rotor(canvas, centre + Vector2(31, -58).rotated(roll), 26.0, .46, sky.age * 51.0, roll)
			rotor(canvas, centre + Vector2(32, 46).rotated(roll), 31.0, .62, sky.age * 54.0, roll)
			if targeting:
				paint_aim(canvas, motion, sky, craft, centre)
			elif craft.has("shot_at") and sky.age - float(craft.shot_at) < .16:
				var flash = 1.0 - (sky.age - float(craft.shot_at)) / .16
				motion.sprite(canvas, "catch_wisp", muzzle(craft, centre, sky.age), 103.0, Color(1, .75, .47, flash), -.28)

static func rotor(canvas: Node2D, hub: Vector2, radius: float, squash: float, beat: float, roll: float) -> void:
	canvas.draw_set_transform(hub, roll, Vector2(1, squash))
	canvas.draw_circle(Vector2.ZERO, radius, Color(.60, .63, .71, .16), true, -1, true)
	canvas.draw_arc(Vector2.ZERO, radius, beat, beat + PI * .78, 18, Color(.96, .79, .51, .40), 2.8, true)
	for i in range(3):
		var blade = Vector2.from_angle(beat + TAU * i / 3.0)
		var across = blade.orthogonal() * radius * .072
		canvas.draw_colored_polygon(PackedVector2Array([Vector2.ZERO, blade * radius - across, blade * radius * .96 + across]), Color(.66, .65, .72, .46))
	canvas.draw_set_transform(Vector2.ZERO)

static func paint_aim(canvas: Node2D, motion, sky, craft: Dictionary, centre: Vector2) -> void:
	var gun = muzzle(craft, centre, sky.age)
	var dir: Vector2 = craft.aim
	var locked = sky.age - float(craft.alert_at) >= AIM_TIME
	var pulse = .62 + sin(sky.age * 24.0) * .24
	var colour = Color(WARNING, pulse * (.76 if locked else .43))
	for i in range(19):
		var start = gun + dir * (15.0 + i * 42.0)
		canvas.draw_line(start, start + dir * 21.0, colour, 2.4 if locked else 1.4, true)
	motion.halo(canvas, gun, 20.0, WARNING, pulse)
	canvas.draw_circle(gun, 3.0 + pulse * 3.0, Color(WARNING, pulse), true, -1, true)

func paint_shots(g, motion, r, sky) -> void:
	var canvas: Node2D = g.paint_target
	for shot in shots:
		if shot.spent: continue
		var p = shot_point(r, shot, sky.age)
		var direction: Vector2 = (shot.velocity - Vector2(r.speed, 0.0)).normalized()
		var trail = p - direction * 65.0
		canvas.draw_line(p, trail, Color(1, .35, .19, .28), 11.0, true)
		canvas.draw_line(p, p - direction * 42.0, Color("f58445"), 5.0, true)
		canvas.draw_line(p, p - direction * 26.0, Color("fff0ad"), 2.6, true)
		motion.halo(canvas, p, 12.0, WARNING, .60)
