extends RefCounted

const ELDER_DEPTH = .16
const DRAGON_DEPTH = .22
const WITCH_DEPTH = .29

# Anchors are in the coordinates of each plane. Only the camera projection
# changes as the horde rises, so a landmark can be seen again on the way down.
static func project(anchor: Vector2, camera: Vector2, depth: float) -> Vector2:
	return anchor - camera * depth

static func paint(g, r, motion, visibility: float) -> void:
	var s = r.sky
	var canvas: Node2D = g.paint_target
	var left: float = g.scenery.view_left
	var top: float = g.scenery.view_top
	var view = Rect2(Vector2(left, top), Vector2(g.scenery.view_right - left, g.scenery.view_bottom - top))
	var camera = Vector2(r.world_px - s.start_world + left, top)
	var t: float = s.age
	clouds(canvas, motion, view, camera * .13 + Vector2(t * 7.0, 0), false, visibility)

	var elder = project(Vector2(1365.0, -124.0), camera, ELDER_DEPTH)
	if Rect2(Vector2.ZERO, view.size).grow(185.0).has_point(elder):
		paint_elder(canvas, motion, view.position + elder, t, visibility)

	# The flyers cross the distant sky on their own routes. Wrap outside the
	# view so their animation can continue through a long climb.
	var dragon_offset = Vector2(t * 24.0, 12.0 * sin(t * 1.6))
	var witch_offset = Vector2(t * 40.0, 9.0 * sin(t * 2.1))
	var dragon_pose = "dragon_up" if fposmod(t, 1.04) < .49 else "dragon_down"
	flyers(canvas, motion, view, project(Vector2(1645.0, -35.0) - dragon_offset, camera, DRAGON_DEPTH),
		dragon_pose, 108.0, sin(t * 1.7) * .045, Color(.71, .68, .90, visibility * .55))
	flyers(canvas, motion, view, project(Vector2(1800.0, 127.0) - witch_offset, camera, WITCH_DEPTH),
		"witch", 76.0, sin(t * 2.1) * .062, Color(.74, .61, .86, visibility * .60))
	var insects = project(Vector2(1450.0, 288.0) - Vector2(t * 12.0, 0.0), camera, .34)
	insects.x = fposmod(insects.x + 230.0, 2160.0) - 230.0
	if Rect2(Vector2.ZERO, view.size).grow(60.0).has_point(insects):
		for i in range(8):
			var beat = t * 2.2 + float(i) * 2.39
			var mote = view.position + insects + Vector2(sin(beat) * (13.0 + i * 4.9), cos(beat * .77) * (8.0 + i * 2.6))
			var wings = 1.0 + absf(sin(t * 44.0 + i)) * 1.4
			canvas.draw_line(mote - Vector2(wings, 1), mote + Vector2(wings, -1), Color(.58, .47, .72, visibility * .41), 1.0, true)
	clouds(canvas, motion, view, camera * .37 + Vector2(t * 18.0, 0), true, visibility)

static func paint_elder(canvas: Node2D, motion, point: Vector2, time: float, visibility: float) -> void:
	const SIZE = 294.0
	motion.sprite(canvas, "elder", point, SIZE, Color(.67, .62, .85, visibility * .47))
	var box: Rect2 = motion.bounds("elder", point, SIZE)
	var blink = fposmod(time + 1.05, 4.9)
	var opened = smoothstep(.01, .14, blink) * (1.0 - smoothstep(4.67, 4.86, blink))
	for uv in motion.elder_eyes:
		var eye: Vector2 = box.position + box.size * uv
		motion.halo(canvas, eye, 9.0, Color("a5ffdb"), visibility * opened * .31)
		canvas.draw_set_transform(eye, -.06, Vector2(3.7, maxf(.15, 1.5 * opened)))
		canvas.draw_circle(Vector2.ZERO, 1.0, Color(.72, 1.0, .87, visibility * opened * .61), true, -1, true)
	canvas.draw_set_transform(Vector2.ZERO)

static func flyers(canvas: Node2D, motion, view: Rect2, relative: Vector2, pose: String, size: float, roll: float, tint: Color) -> void:
	var point = Vector2(fposmod(relative.x + 250.0, 2380.0) - 250.0,
		fposmod(relative.y + 180.0, 1110.0) - 180.0)
	if Rect2(Vector2.ZERO, view.size).grow(90.0).has_point(point):
		motion.sprite(canvas, pose, view.position + point, size, tint, roll)

static func clouds(canvas: Node2D, motion, view: Rect2, camera: Vector2, near: bool, visibility: float) -> void:
	var cell = Vector2(768.0, 309.0) if near else Vector2(920.0, 355.0)
	var bounds = Rect2(camera, view.size).grow(510.0)
	var first = (bounds.position / cell).floor()
	var last = (bounds.end / cell).floor()
	var art = "mist_front" if near else "mist_far"
	for row in range(int(first.y), int(last.y) + 1):
		for col in range(int(first.x), int(last.x) + 1):
			var scatter = Vector2(sin(col * 18.1 + row * 9.37) * 167.0, cos(row * 4.78 + col * 3.17) * 107.0)
			var point = (Vector2(col, row) + Vector2(.52, .48)) * cell + scatter - camera
			var size = (510.0 if near else 716.0) + sin(col * 2.1 + row * 7.2) * 94.0
			var tint = Color(.81, .75, 1.0, visibility * .36) if near else Color(.66, .65, .92, visibility * .23)
			if Rect2(Vector2.ZERO, view.size).grow(size * .60).has_point(point):
				motion.sprite(canvas, art, view.position + point, size, tint)
