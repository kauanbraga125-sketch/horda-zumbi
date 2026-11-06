extends RefCounted

const Air = preload("res://scripts/sky_aircraft.gd")
const SMALL = "meteor_small"
const LARGE = "meteor_large"
const HOLE = "singularity"
const ASTRONAUT = "astronaut"
const SATELLITE = "orbit_satellite"
const UFO = "orbit_shuttle"
const FIRST_METEOR = 6350.0
const AMBER = Color("ff9b62")
const MINT = Color("b3ffdd")
const ROCKS = {
	SMALL: {"size": 114.0, "fall": 124.0, "lift": 960.0, "box": Rect2(-46, -27, 90, 61)},
	LARGE: {"size": 178.0, "fall": 87.0, "lift": 1070.0, "box": Rect2(-72, -37, 144, 80)},
}

static func is_prop(kind: String) -> bool:
	return ROCKS.has(kind) or kind in [HOLE, ASTRONAUT, SATELLITE, UFO]

static func point(r, sky, e: Dictionary, age: float) -> Vector2:
	var t = age + float(e.height) * .008
	var base = Vector2(float(e.x) - r.world_px, r.FLOOR - float(e.height))
	if ROCKS.has(e.kind):
		var rock: Dictionary = ROCKS[e.kind]
		var pass_at = (float(e.x) - sky.start_world - r.ANCHOR) / r.speed
		var fall_time = clampf(age - pass_at, -3.1, 3.0)
		base += Vector2(-45.0 * fall_time, float(rock.fall) * fall_time - rock.box.position.y)
		return base
	if e.kind == HOLE:
		return base + Vector2(0.0, sin(t * .8) * 8.0)
	var swing = Vector2(sin(t * 2.0) * 18.0, sin(t * 2.6) * 12.0 - 46.0)
	if e.kind == ASTRONAUT and e.alert_at >= 0.0:
		swing += Vector2(24, -19) * smoothstep(.04, .76, age - float(e.alert_at))
	return base + swing

static func contact(r, sky, e: Dictionary, now: Vector2, before: Vector2, previous_feet: Dictionary, dt: float) -> void:
	if e.used_at >= 0.0: return
	if ROCKS.has(e.kind):
		rock_contact(r, sky, e, now, before, previous_feet)
	elif e.kind == HOLE:
		hole_contact(r, sky, e, now, before, previous_feet, dt)
	else:
		civil_contact(r, sky, e, now, before, previous_feet)

static func rock_contact(r, sky, e: Dictionary, now: Vector2, before: Vector2, previous_feet: Dictionary) -> void:
	var rock: Dictionary = ROCKS[e.kind]
	var closest: Dictionary = {}
	for m in r.members:
		if m.falling: continue
		var foot = Vector2(m.x, m.y)
		if absf(foot.x - now.x) > 150.0 or absf(foot.y - now.y) > 180.0: continue
		var old: Vector2 = previous_feet.get(m.id, foot)
		var entry = Air.entry(old - before, foot - now, rock.box)
		if entry.is_empty() or (entry.side == "front" and e.get("bumped", false)): continue
		if closest.is_empty() or float(entry.t) < float(closest.t): closest = entry
	if closest.is_empty(): return
	if closest.side == "top":
		e.used_at = sky.age
		sky.boost(r, rock.lift)
		sky.emit_burst(r, "meteor_shatter", now, {"width": rock.size})
		sky.notice = "METEORO QUEBRADO • IMPULSO!"
		if e.get("recovery", false): sky.course.rejoin(r, sky, e)
		r.events.append({"type": "sky_meteor", "prop": e.kind, "x": now.x, "y": now.y,
			"recovery": e.get("recovery", false)})
	else:
		var correction = float(closest.get("correction", 0.0))
		sky.block_rise(r, correction, -96.0)
		if e.get("bumped", false): return
		e.bumped = true
		sky.emit_burst(r, "air_scrape", now)
		sky.notice = "PISE NO METEORO POR CIMA"
	sky.notice_left = 1.10

static func hole_contact(r, sky, e: Dictionary, now: Vector2, before: Vector2, previous_feet: Dictionary, dt: float) -> void:
	var pull = 0.0
	for i in range(r.members.size()):
		var m: Dictionary = r.members[i]
		if m.falling: continue
		var centre = Vector2(m.x, float(m.y) - 53.0)
		var distance = centre.distance_to(now)
		pull = maxf(pull, 1.0 - smoothstep(58.0, 218.0, distance))
		if sky.hurt_left > 0.0 or distance > 106.0: continue
		if not sky.swept_pickup(m, previous_feet, now, before, Vector2(55, 62)): continue
		e.used_at = sky.age
		sky.knock_down(r, -340.0)
		var lost: bool = sky.lose_member(r, i, "black_hole", now)
		sky.notice = "SUGADO • −1 HORDA" if lost else "GRAVIDADE • PERDEU ALTURA"
		sky.notice_left = 1.30
		r.events.append({"type": "sky_singularity", "prop": HOLE, "x": now.x, "y": now.y, "lost": int(lost)})
		return
	if pull <= 0.0: return
	sky.velocity = maxf(-sky.TERMINAL_FALL, sky.velocity - (154.0 + pull * 330.0) * pull * dt)
	if e.alert_at < 0.0:
		e.alert_at = sky.age
		sky.notice = "ATENÇÃO • BURACO NEGRO"
		sky.notice_left = .85
		r.events.append({"type": "sky_cosmic_warn", "x": now.x, "y": now.y})

static func civil_contact(r, sky, e: Dictionary, now: Vector2, before: Vector2, previous_feet: Dictionary) -> void:
	var kind: String = e.kind
	var width = 60.0 if kind == ASTRONAUT else 79.0
	for m in r.members:
		if m.falling: continue
		var dx = now.x - float(m.x)
		var dy = now.y - float(m.y) + 53.0
		if e.alert_at < 0.0 and dx > 0.0 and dx < 455.0 and absf(dy) < 175.0:
			e.alert_at = sky.age
		if absf(dx) > width + 45.0 or absf(dy) > 112.0: continue
		if not sky.swept_pickup(m, previous_feet, now, before, Vector2(width, 69)): continue
		e.used_at = sky.age
		var pilot = int(m.id)
		if kind == ASTRONAUT:
			sky.captures.add(r, now, pilot, kind, -1, 0.0, "orbit_astro_caught")
		else:
			var count = 2 if kind == UFO else 1
			var sprite = "orbit_alien_caught" if kind == UFO else "orbit_astro_caught"
			for i in range(count):
				sky.captures.add(r, now + Vector2(15 * i - 7, -16), pilot, kind, i, i * .13, sprite)
			sky.emit_burst(r, "conversion", now)
		sky.notice = "CAPTURANDO ASTRONAUTA" if kind == ASTRONAUT else "CABINE ABERTA • CAPTURANDO"
		sky.notice_left = 1.18
		r.events.append({"type": "sky_orbit_grab", "prop": kind, "x": now.x, "y": now.y})
		return

static func paint(g, motion, sky, e: Dictionary, pos: Vector2) -> void:
	var canvas: Node2D = g.paint_target
	var kind: String = e.kind
	var time = sky.age + float(e.height) * .008
	var used = e.used_at >= 0.0
	var spent = sky.age - float(e.used_at)
	if ROCKS.has(kind):
		if not used: paint_rock(canvas, motion, e, pos, time)
		return
	if kind == HOLE:
		paint_hole(canvas, motion, pos, time, spent if used else -1.0)
		return
	if kind == ASTRONAUT:
		if used: return
		var sprite = "orbit_astro_panic" if e.alert_at >= 0.0 else ("orbit_astro_a" if sin(time * 7.0) > .0 else "orbit_astro_b")
		motion.sprite(canvas, sprite, pos, 133.0, Color.WHITE, sin(time * 2.1) * .19)
		var pack = pos + Vector2(29, 19)
		var shimmer = .38 + sin(time * 27.0) * .24
		motion.halo(canvas, pack, 17, MINT, shimmer)
		return
	if used and spent >= 1.42: return
	var opened = 1.0 - smoothstep(.63, 1.42, spent) if used else 1.0
	var rotation = sin(time * 2.55) * .07 + minf(.30, spent * .24) * float(used)
	var width = 230.0 if kind == SATELLITE else 195.0
	if used: pos += Vector2(-43.0 * spent, 77.0 * spent * spent)
	var key = kind + "_open" if used else kind
	draw_width(canvas, motion, key, pos, width, Color(1, 1, 1, opened), rotation)
	for i in range(3):
		var light = pos + Vector2(-29 + i * 28, 20).rotated(rotation)
		var pulse = .40 + .36 * sin(time * 8.4 - i * 2.6)
		motion.halo(canvas, light, 12.0, MINT if kind == UFO else AMBER, pulse * opened)

static func draw_width(canvas: Node2D, motion, key: String, pos: Vector2, width: float, tint: Color, roll: float) -> void:
	motion.sprite(canvas, key, pos, width / float(motion.frames[key].size.x), tint, roll)

static func paint_rock(canvas: Node2D, motion, e: Dictionary, pos: Vector2, time: float) -> void:
	var rock: Dictionary = ROCKS[e.kind]
	var width: float = rock.size
	var sway = sin(time * 2.2) * .08
	var trail = Vector2(26, -78) * (width / 118.0)
	motion.sprite(canvas, "rise_wind", pos + trail, width * 1.42, Color(1, .55, .37, .47), -1.02)
	motion.halo(canvas, pos, width * .38, AMBER, .28 + sin(time * 14.0) * .12)
	for i in range(8):
		var t = fposmod(time * (1.65 + i * .11) + i * .17, 1.0)
		var ember = pos + trail * (t * 1.75) + Vector2(sin(time * 5.8 + i * 4.8) * 22.0 * t, 0)
		canvas.draw_circle(ember, (3.5 + float(i % 3)) * (1.0 - t * .83), Color(AMBER, (1.0 - t) * .74), true, -1, true)
	draw_width(canvas, motion, e.kind, pos, width, Color.WHITE, sway)
	var cue = pos + Vector2(0, rock.box.position.y - 17.0 + sin(time * 5.8) * 3.0)
	canvas.draw_polyline(PackedVector2Array([cue + Vector2(-7, 3), cue + Vector2(0, -4), cue + Vector2(7, 3)]), MINT, 2.2, true)

static func paint_hole(canvas: Node2D, motion, pos: Vector2, time: float, spent: float) -> void:
	var fade = 1.0 - smoothstep(.88, 1.60, spent)
	if fade <= .0: return
	var pulse = .86 + .14 * sin(time * 6.0)
	motion.halo(canvas, pos, 93.0, Color("ff6c69"), fade * pulse * .40)
	draw_width(canvas, motion, HOLE, pos, 187.0 + 7.0 * pulse, Color(1, .86, .90, fade), sin(time * 1.9) * .15)
	for i in range(13):
		var turn = time * (2.2 + i * .07) + i * .78
		var radius = 26.0 + fposmod(i * 24.7 - time * 32.0, 104.0)
		var offset = Vector2(cos(turn) * radius, sin(turn) * radius * .53).rotated(-.22)
		var p = pos + offset
		var alpha = fade * (1.0 - smoothstep(84.0, 131.0, radius)) * .70
		canvas.draw_line(p, p - offset.orthogonal().normalized() * (5.0 + i % 4), Color(AMBER, alpha), 1.6, true)
