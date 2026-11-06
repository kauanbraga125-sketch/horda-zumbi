extends RefCounted

const ART = "res://assets/art/v155/"
const FLIGHT_ART = "res://assets/art/v156/"
const AIRCRAFT_ART = "res://assets/art/v157/"
const Civil = preload("res://scripts/sky_civilians.gd")
const FLAP = ["bat_up", "bat_mid", "bat_down", "bat_mid"]
const IMPULSE = ["impulse_start", "impulse_open", "impulse_wisps"]
const MINT = Color("b3ffdd")
const LILAC = Color("f7a5ff")
const AMBER = Color("ffc183")

var frames: Dictionary = {}
var elder_eyes: Array[Vector2] = []

func warm() -> void:
	if not frames.is_empty(): return
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(ART + "sky_motion.json"))
	load_frames(ART, manifest)
	for point in manifest.eye_points: elder_eyes.append(Vector2(point[0], point[1]))
	load_frames(FLIGHT_ART, JSON.parse_string(FileAccess.get_file_as_string(FLIGHT_ART + "sky_motion.json")))
	load_frames(AIRCRAFT_ART, JSON.parse_string(FileAccess.get_file_as_string(AIRCRAFT_ART + "aircraft.json")))

func load_frames(directory: String, manifest: Dictionary) -> void:
	for name in manifest.atlases:
		var atlas: Texture2D = load(directory + name + ".webp")
		for key in manifest.atlases[name].tiles:
			var data = manifest.atlases[name].tiles[key]
			var a = data.rect
			var tile = AtlasTexture.new()
			tile.atlas = atlas
			tile.region = Rect2(a[0], a[1], a[2], a[3])
			tile.filter_clip = true
			frames[key] = {"texture": tile, "size": Vector2(data.size[0], data.size[1]) / 512.0,
				"pivot": Vector2(data.pivot[0], data.pivot[1])}

func bounds(name: String, centre: Vector2, scale: float) -> Rect2:
	var f: Dictionary = frames[name]
	var size: Vector2 = f.size * scale
	return Rect2(centre - size * f.pivot, size)

func sprite(canvas: Node2D, name: String, point: Vector2, scale: float, tint: Color = Color.WHITE, angle: float = 0.0) -> void:
	canvas.draw_set_transform(point, angle)
	canvas.draw_texture_rect(frames[name].texture, bounds(name, Vector2.ZERO, scale), false, tint)
	canvas.draw_set_transform(Vector2.ZERO)

func halo(canvas: Node2D, point: Vector2, radius: float, tint: Color, strength: float) -> void:
	for i in range(3, 0, -1):
		canvas.draw_circle(point, radius * float(i) / 3.0, Color(tint, strength * .16), true, -1, true)

func paint_prop(g, r, e: Dictionary, point: Vector2, original: Dictionary) -> void:
	var s = r.sky
	var kind: String = e.kind
	var phase = s.hazard_phase(e)
	var canvas: Node2D = g.paint_target
	if e.used_at >= 0.0 and kind in ["ember", "balloon", "cloud"]: return
	var t = s.age + float(e.height) * .031
	match kind:
		"ember":
			var pulse = sin(t * 8.0)
			var height = 71.0 + pulse * 5.0
			var angle = sin(t * 6.0) * .08
			halo(canvas, point, 25.0 + pulse * 4.0, LILAC, .23 if e.get("recovery", false) else .16)
			g.scenery.sprite(canvas, original.ember, point - Vector2(0, height * .24).rotated(angle), height, Color.WHITE, angle)
		"balloon":
			g.scenery.sprite(canvas, original.balloon, point + Vector2(0, 17), 142.0, Color.WHITE, sin(t * 3.5) * .115)
		"cloud":
			sprite(canvas, "ghost", point, 221.0 + sin(t * 4.6) * 9.0, Color.WHITE, sin(t * 2.4) * .034)
			if e.get("recovery", false):
				sprite(canvas, "catch_wisp", point - Vector2(4, 26), 61.0, Color(1, .94, 1, .64 + sin(t * 5.8) * .24))
		"bat":
			var pose: String = FLAP[posmod(floori(t * 11.0), FLAP.size())]
			var tint = Color.WHITE
			if phase == "warn":
				pose = "bat_warn"
				tint = Color("ffdabf")
				halo(canvas, point - Vector2(22, 4), 28.0, AMBER, .35 + sin(t * 21.0) * .12)
			elif phase == "attack":
				pose = "bat_attack"
				var streak = Color(.94, .40, .34, .21)
				for i in range(3):
					var start = point + Vector2(19 + i * 8, -17 + i * 15)
					canvas.draw_line(start, start + Vector2(68 - i * 7, -3), streak, 2.0, true)
			elif phase == "recover" and s.age - e.alert_at < e.warning + e.attack + .36:
				pose = "bat_recover"
			sprite(canvas, pose, point, 192.0, tint, sin(t * 4.0) * .035)
		"storm":
			var tint = Color("f1dff8")
			if phase == "warn" or phase == "attack":
				var pulse = .6 + sin(t * 26.0) * .3
				tint = tint.lerp(AMBER, pulse * .39)
				halo(canvas, point + Vector2(0, 18), 67, AMBER, .26 * pulse)
				for i in range(3):
					var a = point + Vector2(-31 + i * 31, 17 + sin(t * 15 + i) * 4)
					var b = a + Vector2(-5, 12 + sin(t * 15 + i * 2.0) * 5)
					canvas.draw_polyline(PackedVector2Array([a, b, b + Vector2(7, -2), b + Vector2(5, 10)]), Color(AMBER, .65 * pulse), 1.7, true)
			if phase == "attack":
				var reach: float = s.strike_length(e)
				var bolt: Dictionary = frames.bolt
				var scale = reach / float(bolt.size.y)
				var brightness = .85 + sin(t * 56.0) * .15
				sprite(canvas, "bolt", point + Vector2(0, 12 + reach * .5), scale, Color(1, .92, .86, brightness), sin(t * 28.0) * .035)
			sprite(canvas, "storm_body", point - Vector2(0, 10), 172.0 + sin(t * 4.8) * 6.0, tint, sin(t * 2.4) * .055)
	if kind in ["balloon", "cloud"]:
		var cue = point - Vector2(0, (65.0 if kind == "balloon" else 50.0) + sin(t * 4.0) * 5.0)
		canvas.draw_polyline(PackedVector2Array([cue + Vector2(-7, 3), cue + Vector2(0, -4), cue + Vector2(7, 3)]), MINT, 2.2, true)

func burst_particles(canvas: Node2D, origin: Vector2, t: float, tint: Color, count: int, speed: float, seed: float) -> void:
	var fade = (1.0 - t) * (1.0 - t)
	for i in range(count):
		var angle = float(i) * TAU / count + seed
		var direction = Vector2.from_angle(angle)
		var point = origin + direction * (speed * t * (1.0 + (i % 3) * .19))
		point.y -= 16.0 * sin(t * PI * .5)
		var size = (2.0 + float(i % 3)) * (1.0 - t * .65)
		canvas.draw_line(point - direction * size * 2.6, point, Color(tint, fade * .52), size * .66, true)
		canvas.draw_circle(point, size * .66, Color(tint.lerp(Color.WHITE, .45), fade), true, -1, true)

func paint_bursts(g, r) -> void:
	var s = r.sky
	var canvas: Node2D = g.paint_target
	for b in s.bursts:
		var elapsed = s.age - float(b.at)
		var t = clampf(elapsed / .68, 0, 1)
		if t >= 1.0: continue
		var origin = Vector2(float(b.x) - r.world_px, b.y)
		var fade = 1.0 - smoothstep(.17, 1.0, t)
		match b.kind:
			"impulse":
				var frame = 0 if elapsed < .10 else (1 if elapsed < .23 else 2)
				var tint = Color(1, .93, 1, fade)
				var drop = 136.0 * elapsed
				sprite(canvas, IMPULSE[frame], origin + Vector2(-18.0 * t, drop), float(b.width) * (1.12 + .38 * t), tint, .25)
				burst_particles(canvas, origin + Vector2(-8, 28 + drop), t, LILAC, 9, 92.0, .35)
			"civil":
				Civil.paint_capture(canvas, self, b.civil, origin, t, fade)
			"conversion":
				sprite(canvas, "catch_wisp", origin, 92.0 + 42.0 * t, Color(.93, .72, 1, fade))
				burst_particles(canvas, origin, t, LILAC, 13, 94.0, .48)
			"air_scrape":
				sprite(canvas, "catch_wisp", origin, 109.0 + 75.0 * t, Color(1, .75, .48, fade))
				burst_particles(canvas, origin, t, AMBER, 16, 147.0, .62)
			"ember":
				halo(canvas, origin, 30.0 + 54.0 * t, LILAC, .70 * fade)
				burst_particles(canvas, origin, t, LILAC, 12, 67.0, .23)
				if t < .40:
					var spoke = 20.0 * (1.0 - t / .40)
					canvas.draw_line(origin - Vector2(spoke, 0), origin + Vector2(spoke, 0), Color(LILAC, fade), 2.1, true)
					canvas.draw_line(origin - Vector2(0, spoke), origin + Vector2(0, spoke), Color.WHITE, 2.0, true)
			"balloon":
				halo(canvas, origin, 49.0 + 37.0 * t, MINT, fade * .6)
				var texture: AtlasTexture = frames.skull_shards.texture
				var source: Rect2 = texture.region
				for i in range(2):
					var part = Rect2(source.position + Vector2(source.size.x * .5 * i, 0), source.size * Vector2(.5, 1))
					var direction = -1.0 if i == 0 else 1.0
					var piece = origin + Vector2(direction * (19.0 + t * 86.0), -49.0 * t + 48.0 * t * t)
					var size = Vector2(60.0, 67.0) * (1.0 - .24 * t)
					canvas.draw_set_transform(piece, direction * t * 1.9)
					canvas.draw_texture_rect_region(texture.atlas, Rect2(-size * .5, size), part, Color(1, 1, 1, fade))
				canvas.draw_set_transform(Vector2.ZERO)
				burst_particles(canvas, origin, t, MINT, 15, 107.0, .13)
			"cloud":
				var squashed = elapsed < .16
				var cloud = "ghost_squash" if squashed else "ghost"
				sprite(canvas, cloud, origin + Vector2(0, 13.0 * t), 224.0 + t * 54.0, Color(1, 1, 1, fade))
				for side in [-1.0, 1.0]:
					sprite(canvas, "mist_far", origin + Vector2(side * (59.0 + t * 106.0), -21.0 * t), 85.0 + t * 80.0, Color(.65, .96, .83, fade * .45))
				burst_particles(canvas, origin - Vector2(0, 21.0), t, MINT, 9, 75.0, -.23)
			"casualty":
				var foot = origin + Vector2(-110.0 * elapsed, 85.0 * elapsed + 388.0 * elapsed * elapsed)
				g.actor.paint(canvas, int(b.member_kind), foot, 112.0, 0.0, "fall", elapsed, 0.0,
					Color(1, .75, .73, fade), false, 1.0, true, elapsed, 520.0, b.wear)
				burst_particles(canvas, origin - Vector2(0, 39), t, Color("ff9a85"), 8, 82.0, 1.0)

func paint_speed(g, r) -> void:
	var s = r.sky
	var falling = smoothstep(265.0, 1090.0, -s.velocity)
	var rising = smoothstep(495.0, 865.0, s.velocity) * (.50 + .50 * s.boost_left / .35)
	var strength = maxf(falling, rising)
	if strength < .02: return
	var canvas: Node2D = g.paint_target
	var left: float = g.scenery.view_left
	var top: float = g.scenery.view_top
	var span: float = g.scenery.view_right - left
	var height: float = g.scenery.view_bottom - top
	var is_falling = falling > rising
	var art = "fall_wind" if is_falling else "rise_wind"
	for i in range(7):
		var x = left - 112.0 + fposmod(float(i) * 207.7 - (r.world_px - s.start_world) * .56, span + 224.0)
		var y = top - 135.0 + fposmod(float(i) * 184.2 + s.altitude * .82, height + 270.0)
		var at_edge = smoothstep(0.0, span * .27, absf(x - left - span * .51))
		var alpha = strength * lerpf(.12, .52 if is_falling else .42, at_edge)
		var size = (80.0 if is_falling else 77.0) + (54.0 + float(i % 3) * 19.0) * strength
		var tint = Color(.71, .78, 1, alpha) if is_falling else Color(.77, .95, 1, alpha)
		sprite(canvas, art, Vector2(x, y), size, tint, -.31 if is_falling else -1.17)

func paint_landing(g, r) -> void:
	var hit: Dictionary = r.sky.landing
	if hit.is_empty(): return
	var t = (r.elapsed - float(hit.at)) / .82
	if t < 0.0 or t >= 1.0: return
	var x = float(hit.x) - r.world_px
	var ground: float = r.ground_y(x)
	var point = Vector2(x, ground + 3.0)
	var canvas: Node2D = g.paint_target
	var expansion = 1.0 - exp(-t * 9.0)
	var fade = 1.0 - smoothstep(.18, 1.0, t)
	var force: float = hit.force
	var scale = (90.0 + 278.0 * expansion) * force
	var size: Vector2 = frames.impact.size * scale
	sprite(canvas, "impact", point - Vector2(0, size.y * .49), scale, Color(1, .90, .86, fade))
	for i in range(12):
		var side = -1.0 if i % 2 == 0 else 1.0
		var dx = (80.0 + i * 15.0) * t * side * force
		var dy = minf(0, (-195.0 - float(i % 5) * 29.0) * t + 340.0 * t * t)
		var p = point + Vector2(dx, dy)
		var v = Vector2.from_angle(t * side * 9.0 + i * 1.23) * (3.3 + float(i % 4))
		canvas.draw_colored_polygon(PackedVector2Array([p - v, p + v.rotated(.82), p + v, p + v.rotated(-1.25)]), Color(.39, .32, .40, fade))
