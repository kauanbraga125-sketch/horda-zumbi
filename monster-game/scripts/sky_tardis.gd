extends RefCounted

const KIND = "tardis"
const MIN_HEIGHT = 9700.0
const SIZE = 166.0
const CYCLE = .58
const OPEN_AT = 2.0 * CYCLE
const EJECT_TIME = .31
const EXIT_GAP = .22
const BEATS = [[.23, "rewind"], [CYCLE, "repeat"], [CYCLE + .23, "rewind"], [OPEN_AT, "open"]]
const TRAVELERS = ["tardis_doctor", "tardis_amy", "tardis_rory"]
const CYAN = Color("8aeaff")
const VIOLET = Color("a58cff")
const GOLD = Color("ffc77f")
const EDGES = [
	Vector2(0, 0), Vector2(.41, 0), Vector2(.79, 0), Vector2(1, 0),
	Vector2(1, .36), Vector2(1, .71), Vector2(1, 1), Vector2(.63, 1),
	Vector2(.28, 1), Vector2(0, 1), Vector2(0, .66), Vector2(0, .28),
]

var started_at = -1.0
var capturer = -1
var next_beat = 0
var released = 0
var converted = 0
var impact_offset = Vector2.ZERO

func clear() -> void:
	started_at = -1.0
	capturer = -1
	next_beat = 0
	released = 0
	converted = 0

static func drift(t: float) -> Vector2:
	return Vector2(sin(t * 1.9) * 13.0, sin(t * 2.7) * 11.0 - 53.0)

func contact(r, sky, object: Dictionary, point: Vector2, previous: Vector2, previous_feet: Dictionary) -> void:
	if started_at >= 0.0: return
	for member in r.members:
		if member.falling or not sky.swept_pickup(member, previous_feet, point, previous, Vector2(55, 89)): continue
		object.used_at = sky.age
		started_at = sky.age
		capturer = int(member.id)
		impact_offset = point - anchor(r, sky)
		sky.notice = "TARDIS • LOOP TEMPORAL"
		sky.notice_left = OPEN_AT + .14
		r.events.append({"type": "sky_tardis_grab", "x": point.x, "y": point.y})
		return

func anchor(r, sky) -> Vector2:
	var lead: int = r.leader_index()
	var x = float(r.members[lead].x) if lead >= 0 else float(r.ANCHOR)
	return Vector2(x + 122.0, r.FLOOR - sky.altitude - 92.0)

static func exit_progress(elapsed: float, index: int) -> float:
	return (elapsed - OPEN_AT - .09 - float(index) * EXIT_GAP) / EJECT_TIME

static func exit_point(cabin: Vector2, index: int, u: float) -> Vector2:
	var ease = smoothstep(0.0, 1.0, u)
	return cabin + Vector2(-108.0 * ease, 15.0 - sin(u * PI) * 29.0 + (float(index) - 1.0) * 35.0 * ease)

func release(r, sky, point: Vector2) -> void:
	var sprite: String = TRAVELERS[released]
	sky.captures.add(r, point, capturer, KIND, -1, 0.0, sprite)
	r.events.append({"type": "sky_tardis_release", "traveler": sprite, "x": point.x, "y": point.y})
	released += 1

func advance(r, sky) -> void:
	if started_at < 0.0 or released == TRAVELERS.size(): return
	var elapsed: float = sky.age - started_at
	var centre = anchor(r, sky) + impact_offset * (1.0 - smoothstep(0.0, .46, elapsed))
	while next_beat < BEATS.size() and elapsed >= float(BEATS[next_beat][0]):
		var phase: String = BEATS[next_beat][1]
		r.events.append({"type": "sky_tardis_phase", "phase": phase, "x": centre.x, "y": centre.y})
		next_beat += 1
		if phase == "open":
			sky.notice = "A PORTA ABRIU • CAPTURANDO!"
			sky.notice_left = 1.36
	while released < TRAVELERS.size() and exit_progress(elapsed, released) >= 1.0:
		release(r, sky, exit_point(centre, released, 1.0))

func confirm_capture(sky) -> void:
	converted += 1
	if converted == TRAVELERS.size():
		sky.notice = "+3 ALMAS • DOUTOR E COMPANHEIROS"
		sky.notice_left = 1.55

func settle(r, sky) -> void:
	if started_at < 0.0: return
	while released < TRAVELERS.size():
		release(r, sky, exit_point(anchor(r, sky), released, 1.0))

static func paint_idle(g, motion, point: Vector2, time: float) -> void:
	var canvas: Node2D = g.paint_target
	var roll = sin(time * 1.7) * .10
	var beacon = point + Vector2(0, -SIZE * .48).rotated(roll)
	var pulse = .42 + .36 * pow(.5 + .5 * sin(time * 7.0), 3.0)
	motion.halo(canvas, beacon, 26.0, CYAN, pulse)
	for i in range(5):
		var turn = time * 1.85 + float(i) * TAU / 5.0
		var glint = point + Vector2(cos(turn) * 58.0, sin(turn) * 19.0).rotated(-.35)
		canvas.draw_circle(glint, 1.8, Color(CYAN, .24 + .13 * sin(turn)), true, -1, true)
	motion.sprite(canvas, "tardis_closed", point, SIZE, Color.WHITE, roll)
	canvas.draw_circle(beacon, 3.0, Color(GOLD, pulse), true, -1, true)

func paint(g, motion, sky, r) -> void:
	if started_at < 0.0: return
	var elapsed: float = sky.age - started_at
	var fade = 1.0 - smoothstep(OPEN_AT + .68, OPEN_AT + 1.18, elapsed)
	if fade <= 0.0: return
	var canvas: Node2D = g.paint_target
	# The cabinet stays in view as the camera follows the horde out of the impact.
	var point = anchor(r, sky) + impact_offset * (1.0 - smoothstep(0.0, .46, elapsed))
	if elapsed < OPEN_AT:
		paint_loop(canvas, motion, point, elapsed)
		return
	var opening = smoothstep(OPEN_AT, OPEN_AT + .17, elapsed)
	motion.halo(canvas, point + Vector2(0, 12), 78.0, GOLD, .61 * fade * opening)
	var sprite = "tardis_closed" if opening <= .005 else "tardis_open"
	motion.sprite(canvas, sprite, point, SIZE, Color(1, 1, 1, fade))
	if opening > .005 and opening < 1.0:
		paint_doors(canvas, motion, point, opening)
	paint_clock(canvas, point, (elapsed - OPEN_AT) * -2.4, 88.0 + (1.0 - fade) * 31.0, fade * .38)
	for i in range(released, TRAVELERS.size()):
		var u = exit_progress(elapsed, i)
		if u <= 0.0 or u >= 1.0: continue
		var body = exit_point(point, i, u)
		var emerge = smoothstep(0.0, .73, u)
		motion.halo(canvas, body, 26.0, GOLD, sin(u * PI) * .49)
		motion.sprite(canvas, TRAVELERS[i] + "_drift", body, lerpf(31.0, 122.0, emerge),
			Color(1.0, .95, .88, smoothstep(0.0, .23, u)), sin(u * PI) * (.25 - i * .25))

static func paint_doors(canvas: Node2D, motion, point: Vector2, opening: float) -> void:
	var tile: AtlasTexture = motion.frames.tardis_closed.texture
	var rect: Rect2 = motion.bounds("tardis_closed", point, SIZE)
	# The moving leaves pivot at the blue posts in the closed texture.
	for hinge in [.142, .827]:
		var seam = .484
		var top = .352
		var bottom = .925
		var inner = lerpf(seam, hinge, opening * .94)
		var inset = .105 * opening
		var corners = PackedVector2Array([Vector2(hinge, top), Vector2(seam, top),
			Vector2(seam, bottom), Vector2(hinge, bottom)])
		var panel = PackedVector2Array([Vector2(hinge, top), Vector2(inner, top + inset),
			Vector2(inner, bottom - inset), Vector2(hinge, bottom)])
		var uv = PackedVector2Array()
		for i in range(panel.size()):
			panel[i] = rect.position + panel[i] * rect.size
			uv.append((tile.region.position + corners[i] * tile.region.size) / tile.atlas.get_size())
		canvas.draw_polygon(panel, PackedColorArray([Color(1, 1, 1, 1.0 - smoothstep(.69, 1.0, opening))]), uv, tile.atlas)

static func paint_loop(canvas: Node2D, motion, point: Vector2, elapsed: float) -> void:
	var phase = fposmod(elapsed, CYCLE) / CYCLE
	# Both the fragments and the light use the same progress on the way back.
	var scatter = smoothstep(0.0, .36, phase) * (1.0 - smoothstep(.40, 1.0, phase))
	var second = elapsed >= CYCLE
	var accent = VIOLET if second else CYAN
	motion.halo(canvas, point, 98.0 + scatter * 43.0, accent, .30 + scatter * .58)
	for i in range(1, 4):
		var trail = Vector2(16.0 * i, -8.0 * i).rotated(elapsed * 5.0) * scatter
		motion.sprite(canvas, "tardis_closed", point + trail, SIZE * (1.0 + i * .08 * scatter),
			Color(accent, .23 * scatter / float(i)), i * .075 * scatter)
	paint_clock(canvas, point, scatter * 2.15 * (-1.0 if second else 1.0), 82.0 + scatter * 33.0, .26 + scatter * .74)
	if scatter > .015:
		paint_shards(canvas, motion, point, scatter, accent)
	else:
		motion.sprite(canvas, "tardis_closed", point, SIZE, Color.WHITE)
	for i in range(15):
		var angle = float(i) * 2.4
		var ray = Vector2.from_angle(angle)
		var spark = point + ray * (28.0 + scatter * (60.0 + (i % 5) * 10.0))
		canvas.draw_line(spark, spark + ray * (6.0 + i % 5) * scatter, Color(accent, scatter * .78), 1.5, true)

static func paint_clock(canvas: Node2D, point: Vector2, turn: float, radius: float, alpha: float) -> void:
	canvas.draw_arc(point, radius, turn - 1.3, turn + .87, 24, Color(CYAN, alpha * .58), 2.0, true)
	canvas.draw_arc(point, radius - 7.0, turn + 1.95, turn + 4.62, 24, Color(VIOLET, alpha * .62), 1.4, true)
	for i in range(12):
		var dir = Vector2.from_angle(turn + i * TAU / 12.0)
		var notch = 9.0 if i % 3 == 0 else 5.0
		canvas.draw_line(point + dir * (radius - notch), point + dir * radius, Color(CYAN, alpha * .69), 1.6, true)

static func paint_shards(canvas: Node2D, motion, point: Vector2, scatter: float, light: Color) -> void:
	var tile: AtlasTexture = motion.frames.tardis_closed.texture
	var atlas_size = tile.atlas.get_size()
	var rect: Rect2 = motion.bounds("tardis_closed", point, SIZE)
	var fracture = Vector2(.53, .48)
	for i in range(EDGES.size()):
		var a: Vector2 = EDGES[i]
		var b: Vector2 = EDGES[(i + 1) % EDGES.size()]
		var pivot = (a + b + fracture) / 3.0
		var direction = ((pivot - fracture) * rect.size).normalized()
		var gap = direction * scatter * (36.0 + (i % 5) * 9.0)
		var rotation = scatter * (float(i % 4) - 1.5) * .53
		var triangle = PackedVector2Array()
		var uv = PackedVector2Array()
		for vertex in [a, b, fracture]:
			triangle.append(rect.position + pivot * rect.size + ((vertex - pivot) * rect.size).rotated(rotation) + gap)
			uv.append((tile.region.position + vertex * tile.region.size) / atlas_size)
		var tint = Color.WHITE.lerp(light, .26 * scatter)
		canvas.draw_polygon(triangle, PackedColorArray([tint, tint, tint]), uv, tile.atlas)
