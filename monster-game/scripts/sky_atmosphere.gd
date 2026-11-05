extends RefCounted

static func paint(g, r, motion) -> void:
	var s = r.sky
	var visibility = smoothstep(460.0, 1030.0, s.altitude)
	if visibility <= 0.0: return
	var canvas: Node2D = g.paint_target
	var left: float = g.scenery.view_left
	var top: float = g.scenery.view_top
	var span: float = g.scenery.view_right - left
	var height: float = g.scenery.view_bottom - top
	var travel: float = r.world_px - s.start_world
	var t: float = s.age

	for i in range(3):
		var x = left - 340.0 + fposmod(span * .46 + i * span * .58 - travel * .11, span + 680.0)
		var y = top - 150.0 + fposmod(188.0 + i * 251.0 + s.altitude * .13, height + 300.0)
		motion.sprite(canvas, "mist_far", Vector2(x, y), 670.0, Color(.63, .65, .91, visibility * .33))

	# The apparition emerges from the distant mist for only part of each cycle.
	var apparition = fposmod(t, 26.0)
	var reveal = smoothstep(2.9, 5.2, apparition) * (1.0 - smoothstep(10.8, 14.3, apparition))
	if reveal > 0.0:
		var centre = Vector2(left + span * .75 - (apparition - 6.0) * 12.0,
			top + height * .56 + sin(t * .55) * 20.0)
		var size = minf(span * .63, 650.0)
		var opacity = visibility * reveal
		motion.sprite(canvas, "elder", centre, size, Color(.68, .62, .88, opacity * .55))
		var box: Rect2 = motion.bounds("elder", centre, size)
		var blink = fposmod(t + 1.05, 4.25)
		var opened = smoothstep(.03, .16, blink) * (1.0 - smoothstep(4.05, 4.23, blink))
		for uv in motion.elder_eyes:
			var point: Vector2 = box.position + box.size * uv
			motion.halo(canvas, point, 23.0, Color("a5ffdb"), opacity * opened * .4)
			canvas.draw_set_transform(point, -.06, Vector2(9.0, maxf(.15, 3.6 * opened)))
			canvas.draw_circle(Vector2.ZERO, 1.0, Color(.72, 1.0, .87, opacity * opened * .87), true, -1, true)
		canvas.draw_set_transform(Vector2.ZERO)

	var dragon_x = left - 235.0 + fposmod(span + 290.0 - t * 59.0 - travel * .10, span + 470.0)
	var dragon_y = top + height * .31 + sin(t * 1.4) * 25.0 + sin(s.altitude * .0009) * 32.0
	var pose = "dragon_up" if fposmod(t, .86) < .46 else "dragon_down"
	motion.sprite(canvas, pose, Vector2(dragon_x, dragon_y), 254.0, Color(.75, .71, .95, visibility * .66), sin(t * 1.7) * .09)
	var witch_x = left - 150.0 + fposmod(span * 1.31 - t * 88.0 - travel * .19, span + 320.0)
	var witch_y = top + height * .74 + sin(t * 2.4) * 19.0
	motion.sprite(canvas, "witch", Vector2(witch_x, witch_y), 154.0, Color(.71, .61, .85, visibility * .70), sin(t * 2.4) * .10)

	for i in range(3):
		var x = left - 290.0 + fposmod(span * .29 + i * span * .52 - travel * .24 - t * 17.0, span + 580.0)
		var y = top - 98.0 + fposmod(i * 227.0 + s.altitude * .28 + t * 19.0, height + 196.0)
		motion.sprite(canvas, "mist_front", Vector2(x, y), 435.0 + float(i) * 64.0, Color(.88, .78, 1.0, visibility * .22))
	# Two small swarms crossing the nearer haze. Their wing flicker reads at game scale.
	for i in range(14):
		var row = float(i / 7)
		var phase = t * (2.7 + .18 * i) + i * 2.26
		var x = left - 25.0 + fposmod(span * (.74 + row * .33) + sin(phase) * (18.0 + i * 4.5) - travel * .34, span + 50.0)
		var y = top + height * (.40 + row * .24) + cos(phase * .81) * (15.0 + i * 2.8)
		var point = Vector2(x, y)
		var wing = 1.2 + absf(sin(t * 44.0 + i)) * 2.1
		canvas.draw_line(point - Vector2(wing, 1.5), point + Vector2(wing, -1.5), Color(.71, .61, .82, visibility * .32), 1.0, true)
		canvas.draw_circle(point, 1.55, Color(.13, .08, .19, visibility * .79), true, -1, true)
