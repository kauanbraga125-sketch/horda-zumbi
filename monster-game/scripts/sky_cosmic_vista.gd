extends RefCounted

const SkyPlanes = preload("res://scripts/sky_atmosphere.gd")
const Hauntings = preload("res://scripts/sky_hauntings.gd")
const Deep = preload("res://scripts/sky_deep_landscape.gd")
const Regions = preload("res://scripts/sky_region_scenery.gd")
const Pop = preload("res://scripts/sky_pop_encounters.gd")
const START = 4320.0
const FULL = 6860.0
const SPACE_START = 9250.0
const SPACE_FULL = 10650.0
const AMBER = Color("ffb582")

static func blend(height: float) -> float:
	return smoothstep(START, FULL, height)

static func space_blend(height: float) -> float:
	return smoothstep(SPACE_START, SPACE_FULL, height)

static func covers_background(height: float, view_height: float) -> bool:
	return height >= SPACE_FULL or height - view_height * .39 >= FULL

static func paint(g, r, motion) -> void:
	var s = r.sky
	var canvas: Node2D = g.paint_target
	var left: float = g.scenery.view_left
	var top: float = g.scenery.view_top
	var view = Rect2(Vector2(left, top), Vector2(g.scenery.view_right - left, g.scenery.view_bottom - top))
	var height: float = s.altitude
	var opacity = blend(height + 120.0)
	if opacity <= 0.0 and height + view.size.y * .39 <= START: return
	var camera = Vector2(r.world_px - s.start_world + left, top)
	var time: float = s.age
	var space = space_blend(height)
	if space < 1.0: plate(canvas, motion.frames.orbit_sky.texture, view, camera, height)
	if space > .0: paint_deep_space(canvas, motion, view, camera, time, space)
	Regions.paint_orbit(canvas,motion,view,camera,time,opacity*(1.0-space))
	paint_stars(canvas, view, camera, time, opacity, AMBER.lerp(Color("a6ddff"), space))
	Pop.paint_orbit(canvas,motion,view,camera,time,opacity)
	Hauntings.passers(canvas, motion, view, camera, time, opacity * (1.0 - space * .67))
	s.hauntings.paint_orbit(canvas, motion, view, camera, space)

	var air = opacity * (1.0 - space * .67)
	var dark = Color(.74, .62, .82, air * .60)
	var serpent = Deep.project(Vector2(1420-time*9.0,-6700+12.0*sin(time*.77)),view,camera,.025)
	motion.sprite(canvas, "leviathan", serpent, 548.0, dark, sin(time * .82) * .065)
	Regions.veil_orbit(canvas,motion,serpent,air,"leviathan")
	var ship = Deep.project(Vector2(1180-time*5.0,-5700+sin(time*.38)*8.0),view,camera,.018)
	motion.sprite(canvas, "derelict", ship, 440.0, Color(.76, .64, .80, air * .48), -.045)
	Regions.veil_orbit(canvas,motion,ship,air,"ship")
	var windows = ship + Vector2(-174.0, -8.0)
	var flicker = .5 + .25 * sin(time * 7.0) + .17 * sin(time * 23.0)
	motion.halo(canvas, windows, 17.0, AMBER, air * flicker * .40)

	for i in range(3):
		var offset = Vector2(time * (22.0 + i * 10.0), sin(time * (1.4 + i * .16)) * 12.0)
		var position = Deep.project(Vector2(1015+i*243,-5400-i*920)-offset,view,camera,.025+i*.006)
		var light = .46 + .34 * pow(absf(sin(time * 2.9 + i)), 4.0)
		motion.sprite(canvas, "orbit_saucer_far", position, 74.0 - i * 12.0, Color(.81, .72, 1, air * .65), sin(time * 1.8 + i) * .09)
		motion.halo(canvas, position + Vector2(0, 5), 11.0 - i * 2.0, Color("e9a9ff"), light * air)

	var watch = Deep.project(Vector2(1260,-8350),view,camera,.012)
	var blink = fposmod(time + .4, 5.7)
	var shut = smoothstep(4.68, 4.81, blink) * (1.0 - smoothstep(4.89, 5.04, blink))
	var stare = .32 + .28 * sin(time * .68)
	Regions.paint_watcher_back(canvas,motion,watch,air)
	motion.sprite(canvas,"orbit_eyes",watch,500.0,Color(1,.79,.67,air*(1.0-shut)*stare))
	if shut > .01:
		motion.sprite(canvas,"orbit_eyes_shut",watch,500.0,Color(1,.77,.63,air*shut*stare))
	Regions.paint_watcher_front(canvas,motion,watch,time,air)

	if space < .99:
		for i in range(3):
			var fog = layer_point(view, camera, Vector2(i * 751 + 450, -595 + i * 256), .27,
				Vector2(time * (14 + i * 4), 0), 430.0)
			motion.sprite(canvas, "orbit_dust", fog, 535.0 + i * 38.0,
				Color(.81, .48, .62, opacity * .32 * (1.0 - space)), -.07 + .05 * i)

static func paint_deep_space(canvas: Node2D, motion, view: Rect2, camera: Vector2, time: float, alpha: float) -> void:
	var night = Color(Color("060c19"), alpha)
	var blue = Color(Color("0a152a"), alpha)
	var quad = PackedVector2Array([view.position, Vector2(view.end.x, view.position.y),
		view.end, Vector2(view.position.x, view.end.y)])
	canvas.draw_polygon(quad, PackedColorArray([night, night, blue, blue]))
	Deep.paint_background(canvas,motion,view,camera,time,alpha)

static func plate(canvas: Node2D, texture: Texture2D, view: Rect2, camera: Vector2, height: float) -> void:
	# Start with a thin strip of high atmosphere, then fade it down over the old sky.
	var pan = clampf(camera.x * .000006, 0.0, .18)
	var lift = .10 * (1.0 - smoothstep(START, FULL + 3200.0, height))
	for i in range(7):
		var t0 = float(i) / 7.0
		var t1 = float(i + 1) / 7.0
		var y0 = view.position.y + t0 * view.size.y
		var y1 = view.position.y + t1 * view.size.y
		var alpha0 = blend(height + (.5 - t0) * view.size.y * .78)
		var alpha1 = blend(height + (.5 - t1) * view.size.y * .78)
		if maxf(alpha0, alpha1) < .002: continue
		var polygon = PackedVector2Array([Vector2(view.position.x, y0), Vector2(view.end.x, y0),
			Vector2(view.end.x, y1), Vector2(view.position.x, y1)])
		var uv = PackedVector2Array([Vector2(.01 + pan, .01 + lift + t0 * .87), Vector2(.80 + pan, .01 + lift + t0 * .87),
			Vector2(.80 + pan, .01 + lift + t1 * .87), Vector2(.01 + pan, .01 + lift + t1 * .87)])
		var tint = PackedColorArray([Color(1, 1, 1, alpha0), Color(1, 1, 1, alpha0),
			Color(1, 1, 1, alpha1), Color(1, 1, 1, alpha1)])
		canvas.draw_polygon(polygon, tint, uv, texture)

static func layer_point(view: Rect2, camera: Vector2, origin: Vector2, depth: float, drift: Vector2, margin: float) -> Vector2:
	var local = SkyPlanes.project(origin - drift, camera, depth)
	var span = view.size + Vector2.ONE * margin * 2.0
	local.x = fposmod(local.x + margin, span.x) - margin
	local.y = fposmod(local.y + margin, span.y) - margin
	return view.position + local

static func paint_stars(canvas: Node2D, view: Rect2, camera: Vector2, time: float, opacity: float, tint: Color) -> void:
	for i in range(25):
		var depth = .065 + float(i % 4) * .057
		var point = layer_point(view, camera, Vector2(i * 197.3, i * 113.7), depth, Vector2.ZERO, 20.0)
		var twinkle = .22 + .45 * pow(absf(sin(time * (1.7 + depth) + i * 2.14)), 5.0)
		var colour = Color(tint, opacity * twinkle * .55)
		canvas.draw_circle(point, 1.0 + float(i % 4) * .44, colour, true, -1, true)
		if i % 5 == 0:
			canvas.draw_line(point - Vector2(5, -1), point + Vector2(3, -1), Color(colour, colour.a * .45), 1.1, true)
