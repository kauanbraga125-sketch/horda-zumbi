extends RefCounted

const Hauntings = preload("res://scripts/sky_hauntings.gd")
const Landscape = preload("res://scripts/sky_landscape.gd")
const Regions = preload("res://scripts/sky_region_scenery.gd")

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
	clouds(canvas, motion, view, camera * .085 + Vector2(t * 5.0, 0), false, visibility)
	Landscape.paint(canvas,motion,view,camera,t,visibility)
	Hauntings.walker(canvas, motion, view, camera, t, visibility)
	Regions.paint_air(canvas,motion,view,camera,t,visibility)

	var elder = Regions.position("elder",view,camera,t)
	if view.grow(360.0).has_point(elder):
		paint_elder(canvas,motion,elder,t,visibility)
		Regions.paint_elder_front(canvas,motion,elder,t,visibility)

	# Flight paths belong to their sky regions. No viewport-height wrapping.
	var dragon = Regions.position("dragon",view,camera,t)
	var witch = Regions.position("witch",view,camera,t)
	var dragon_pose = "dragon_up" if fposmod(t, 1.04) < .49 else "dragon_down"
	if view.grow(240.0).has_point(dragon):Regions.paint_flight_wake(canvas,motion,dragon,t,false,visibility)
	if view.grow(180.0).has_point(witch):Regions.paint_flight_wake(canvas,motion,witch,t,true,visibility)
	flyers(canvas,motion,view,dragon,dragon_pose,145.0,sin(t*1.7)*.045,Color(.68,.70,.88,visibility*.62))
	flyers(canvas,motion,view,witch,"witch",93.0,sin(t*2.1)*.062,Color(.73,.61,.84,visibility*.65))
	var insects = Regions.position("fireflies",view,camera,t)
	if view.grow(60.0).has_point(insects):
		for i in range(8):
			var beat = t * 2.2 + float(i) * 2.39
			var mote = insects+Vector2(sin(beat)*(13.0+i*4.9),cos(beat*.77)*(8.0+i*2.6))
			var wings = 1.0 + absf(sin(t * 44.0 + i)) * 1.4
			canvas.draw_line(mote - Vector2(wings, 1), mote + Vector2(wings, -1), Color(.58, .47, .72, visibility * .41), 1.0, true)
	clouds(canvas, motion, view, camera * .26 + Vector2(t * 12.0, 0), true, visibility)

static func paint_elder(canvas: Node2D, motion, point: Vector2, time: float, visibility: float) -> void:
	const SIZE = Regions.ELDER_SCALE
	motion.sprite(canvas,"elder",point,SIZE,Color(.58,.63,.81,visibility*.64))
	var box: Rect2 = motion.bounds("elder", point, SIZE)
	var blink = fposmod(time + 1.05, 4.9)
	var opened = smoothstep(.01, .14, blink) * (1.0 - smoothstep(4.67, 4.86, blink))
	for uv in motion.elder_eyes:
		var eye: Vector2 = box.position + box.size * uv
		motion.halo(canvas,eye,12.0,Color("a5ffdb"),visibility*opened*.29)
		canvas.draw_set_transform(eye,-.06,Vector2(5.1,maxf(.15,2.0*opened)))
		canvas.draw_circle(Vector2.ZERO, 1.0, Color(.72, 1.0, .87, visibility * opened * .61), true, -1, true)
	canvas.draw_set_transform(Vector2.ZERO)

static func flyers(canvas: Node2D, motion, view: Rect2, point: Vector2, pose: String, size: float, roll: float, tint: Color) -> void:
	if view.grow(size*1.8).has_point(point):motion.sprite(canvas,pose,point,size,tint,roll)

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
			var size = (376.0 if near else 516.0) + sin(col * 2.1 + row * 7.2) * 65.0
			var tint = Color(.76, .73, .96, visibility * .28) if near else Color(.62, .62, .88, visibility * .19)
			if Rect2(Vector2.ZERO, view.size).grow(size * .60).has_point(point):
				motion.sprite(canvas, art, view.position + point, size, tint)
