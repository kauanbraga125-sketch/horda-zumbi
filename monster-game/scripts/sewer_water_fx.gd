extends RefCounted

enum Cel { WAKE_COMPACT, WAKE_LONG, KEEL_FOAM, IMPACT_START, IMPACT_PEAK, IMPACT_FALL, RIPPLE, STERN_SPRAY, DROP }

# Each region has a transparent gutter in the packed atlas.
const REGIONS = [
	Rect2(6, 62, 308, 67), Rect2(326, 63, 308, 66), Rect2(646, 83, 308, 25),
	Rect2(27, 208, 266, 159), Rect2(326, 211, 308, 154), Rect2(646, 248, 308, 80),
	Rect2(6, 440, 308, 80), Rect2(326, 422, 308, 116), Rect2(772, 412, 56, 135),
]

var atlas: Texture2D = preload("res://assets/art/v151/water_fx.webp")
var shadow: GradientTexture2D

func cel(canvas: Node2D, frame: int, rect: Rect2, opacity: float, tint: Color = Color.WHITE) -> void:
	if opacity <= 0.005: return
	tint.a *= opacity
	canvas.draw_texture_rect_region(atlas, rect, REGIONS[frame], tint)

func droplet(canvas: Node2D, point: Vector2, size: float, angle: float, opacity: float) -> void:
	if opacity <= 0.005: return
	canvas.draw_set_transform(point, angle)
	var extent = Vector2(size * 0.41, size)
	cel(canvas, Cel.DROP, Rect2(-extent * 0.5, extent), opacity)
	canvas.draw_set_transform(Vector2.ZERO)

func ripple(canvas: Node2D, point: Vector2, width: float, clock: float, strength: float = 1.0) -> void:
	for layer in range(2):
		var phase = fposmod(clock * 1.7 + layer * 0.49, 1.0)
		var opacity = smoothstep(0.0, 0.17, phase) * (1.0 - smoothstep(0.52, 1.0, phase))
		var size = Vector2(width * (0.67 + 0.62 * phase), width * (0.11 + 0.07 * phase))
		cel(canvas, Cel.RIPPLE, Rect2(point - size * 0.5, size), strength * opacity * 0.74)

func trail(canvas: Node2D, stern: Vector2, width: float, clock: float, strength: float) -> void:
	var pulse = 0.5 + 0.5 * sin(clock * 7.3)
	var size = Vector2(width * (0.94 + pulse * 0.10), width * 0.15)
	var at = stern - Vector2(size.x - 9, size.y * 0.68)
	var blend = smoothstep(0.12, 0.88, pulse)
	cel(canvas, Cel.WAKE_COMPACT, Rect2(at, size), strength * (1.0 - blend) * 0.82)
	cel(canvas, Cel.WAKE_LONG, Rect2(at + Vector2(-7, 1.5), size + Vector2(7, 0)), strength * blend * 0.82)

func convoy(g, s) -> void:
	if shadow == null:
		var gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.46, 1.0])
		gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.54), Color(1, 1, 1, 0)])
		shadow = GradientTexture2D.new()
		shadow.gradient = gradient
		shadow.fill = GradientTexture2D.FILL_RADIAL
		shadow.fill_from = Vector2(0.5, 0.5)
		shadow.fill_to = Vector2(1, 0.5)
	var canvas: Node2D = g.paint_target
	var entry = s.phase == "entry"
	var exit = s.phase == "exit"
	var rise: float = s.exit_rise(g.runner) if exit else 0.0
	var drive: float = s.entry_launch() * 0.62 if entry else lerpf(0.62, 1.0, smoothstep(0, 0.42, s.ride_age))
	for boat in s.boats:
		var line: float = s.boat_waterline(boat) + rise
		if line > g.scenery.view_bottom + 46.0 or line < g.scenery.view_top - 80.0: continue
		var hull = Vector2(boat.x, boat.y)
		if exit: hull = s.exit_boat(g.runner, boat).p
		var lift = maxf(0, line - hull.y - s.HULL_WATERLINE)
		var grounded = 1.0 - smoothstep(1.0, 21.0, lift)
		var shade = 0.64 * (1.0 - smoothstep(35.0, 187.0, lift))
		canvas.draw_texture_rect(shadow, Rect2(hull.x - 97, line - 10, 194, 27), false, Color(0.025, 0.062, 0.076, shade))
		var clock = s.age + float(boat.id) * 0.39
		cel(canvas, Cel.KEEL_FOAM, Rect2(hull.x - 78, line - 1, 155, 10), grounded * 0.72)
		var dry_for = maxf(0, s.age - float(boat.get("water_touch_at", s.age)))
		var linger = 1.0 - smoothstep(0.025, 0.34, dry_for)
		if linger <= 0.005: continue
		var drift = s.scroll_speed(g.runner) * dry_for * 0.56
		var stern = Vector2(hull.x - 88 - drift, line + 4)
		trail(canvas, stern, 154, clock, drive * linger)
		var spray = grounded * drive * (0.72 + 0.23 * sin(clock * 10.8))
		cel(canvas, Cel.STERN_SPRAY, Rect2(stern.x - 66, stern.y - 24, 74, 28), spray * 0.83)
		for i in range(3):
			var t = fposmod(clock * 3.8 + i * 0.327, 1.0)
			var point = stern + Vector2(-9 - t * (61 + 6 * i), -5 - 40 * t + 32 * t * t)
			droplet(canvas, point, 8.5 - 4.0 * t, -0.87 + 0.55 * t, spray * (1.0 - t) * 0.76)

func crown(canvas: Node2D, frame: int, point: Vector2, width: float, height: float, opacity: float, tint: Color) -> void:
	cel(canvas, frame, Rect2(point.x - width * 0.5, point.y - height * 0.94, width, height), opacity, tint)

func impact(canvas: Node2D, s, item: Dictionary) -> void:
	var age = float(item.age)
	var point = Vector2(item.p)
	point.x -= (s.scroll - float(item.get("scroll", s.scroll))) * 0.58
	var scale = 0.82
	match str(item.get("motion", "impact")):
		"takeoff": scale = 0.48
		"boarding": scale = 0.70
		"landing": scale = 0.96
	if item.explosion: scale = 1.28
	var tint = Color(1.09, 0.88, 0.62) if item.explosion else Color.WHITE
	var rise = smoothstep(0.0, 0.065, age) * (1.0 - smoothstep(0.10, 0.21, age))
	var crest = smoothstep(0.075, 0.18, age) * (1.0 - smoothstep(0.23, 0.44, age))
	var settle = smoothstep(0.22, 0.42, age) * (1.0 - smoothstep(0.49, 0.82, age))
	crown(canvas, Cel.IMPACT_START, point, (61 + 120 * age) * scale, (25 + 121 * age) * scale, rise, tint)
	crown(canvas, Cel.IMPACT_PEAK, point, (109 + 116 * age) * scale, (76 - 43 * age) * scale, crest * 0.95, tint)
	crown(canvas, Cel.IMPACT_FALL, point, (128 + 92 * age) * scale, (43 - 28 * age) * scale, settle * 0.88, tint)
	var ring_size = Vector2((82 + 172 * age) * scale, (15 + 19 * age) * scale)
	var ring_alpha = smoothstep(0.04, 0.17, age) * (1.0 - smoothstep(0.38, 0.95, age))
	cel(canvas, Cel.RIPPLE, Rect2(point - ring_size * 0.5, ring_size), ring_alpha * 0.86, tint)
	for i in range(5):
		var t = age - 0.019 * i
		if t <= 0.0 or t >= 0.74: continue
		var side = -1.0 if i % 2 == 0 else 1.0
		var delta = Vector2(side * (49 + i * 22) * t - t * 25, -t * (141 + i * 21) + t * t * 291)
		var fade = smoothstep(0.0, 0.055, t) * (1.0 - smoothstep(0.31, 0.71, t))
		droplet(canvas, point + delta * scale, (7.0 + i % 3 * 2.0) * scale, -side * 0.71 + t * 0.66, fade * 0.78)

func falling_drops(canvas: Node2D, source: Vector2, length: float, clock: float, amount: int, opacity: float) -> void:
	for i in range(amount):
		var t = fposmod(clock * 1.38 + i * 0.217, 1.0)
		var point = source + Vector2(sin(i * 2.9) * 9.0 - 9.0 * t, length * t * t)
		var fade = smoothstep(0, 0.14, t) * (1.0 - smoothstep(0.83, 1.0, t))
		droplet(canvas, point, 6.0 + t * 9.0, PI + 0.08, opacity * fade)

func wave_base(canvas: Node2D, point: Vector2, width: float, clock: float, strength: float) -> void:
	var pulse = 0.5 + 0.5 * sin(clock * 5.1)
	var centre = point - Vector2(width * 0.43, -4)
	ripple(canvas, centre, width * 1.43, clock, strength * 0.80)
	cel(canvas, Cel.WAKE_LONG, Rect2(centre.x - width * 0.57, centre.y - 15, width * 1.26, 31), strength * (0.79 + pulse * 0.18))
	cel(canvas, Cel.KEEL_FOAM, Rect2(centre.x - width * 0.51, centre.y + 7, width * 1.29, 12), strength * 0.76)
	var spray = Rect2(point.x - 89, point.y - 29 - pulse * 8, 114, 43 + pulse * 5)
	cel(canvas, Cel.STERN_SPRAY, spray, strength * (0.45 + pulse * 0.27))
