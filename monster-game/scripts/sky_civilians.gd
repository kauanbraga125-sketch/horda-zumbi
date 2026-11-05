extends RefCounted

const PARA_OCHRE = "para_ochre"
const PARA_LILAC = "para_lilac"
const JETPACK = "jetpack"
const CIVILIANS = [PARA_OCHRE, PARA_LILAC, JETPACK]
const REACTIONS = ["steady", "nervous", "panic"]

static func is_civil(kind: String) -> bool:
	return kind in CIVILIANS

static func point(e: Dictionary, at: float, base: Vector2) -> Vector2:
	var t = at + float(e.height) * .009
	if e.kind == JETPACK:
		var alarm = smoothstep(0.0, .75, at - float(e.alert_at)) if e.alert_at >= 0.0 else 0.0
		return base + Vector2(sin(t * 2.9) * 13.0 + alarm * 34.0, cos(t * 3.3) * 13.0 - alarm * 23.0)
	var sink = clampf(at - float(e.pass_at), -2.2, 2.2) * 27.0
	return base + Vector2(sin(t * 2.6) * 23.0, sink + cos(t * 2.6) * 8.0 + sin(t * 1.1) * 17.0)

static func alert(e: Dictionary, age: float, centre: Vector2, lead: Dictionary) -> void:
	if e.alert_at >= 0.0 or lead.is_empty(): return
	var ahead = centre.x - float(lead.x)
	if ahead < 0.0 or ahead > 550.0 or absf(centre.y - float(lead.y) + 53.0) > 250.0: return
	e.alert_at = age

static func capture(r, sky, prop: String, centre: Vector2) -> void:
	var kind: int = r.recruit_kind()
	var before: int = r.members.size()
	r.add_member(kind, false, centre + Vector2(0, 47))
	if r.members.size() > before:
		var recruit: Dictionary = r.members[-1]
		recruit.sky_arrival = .36
		sky.spacing[int(recruit.id)] = r.FLOOR - float(recruit.y) - sky.altitude
		r.recruits += 1
		r.refresh_formation()
		sky.reform_left = 1.1
	r.souls += 1
	r.mission_stats.civilians = int(r.mission_stats.get("civilians", 0)) + 1
	sky.emit_burst(r, "civil", centre, {"civil": prop})
	r.events.append({"type": "soul", "x": centre.x, "y": centre.y,
		"kind": kind, "soldier": false, "from_vehicle": false})

static func paint(g, motion, e: Dictionary, centre: Vector2, age: float) -> void:
	if e.used_at >= 0.0: return
	var canvas: Node2D = g.paint_target
	var jet = e.kind == JETPACK
	var t = age + float(e.height) * .009
	var alarm_age = age - float(e.alert_at) if e.alert_at >= 0.0 else -1.0
	var reaction = 0 if alarm_age < 0.0 else (1 if alarm_age < .52 else 2)
	var pose: String = e.kind + "_" + REACTIONS[reaction]
	var roll = sin(t * (3.3 if jet else 2.6)) * (.09 if jet else .15)
	if jet:
		var long_flame = reaction == 2 or sin(t * 21.0) > -.12
		var exhaust = "jet_long" if long_flame else "jet_short"
		var nozzle = centre + Vector2(24, 25).rotated(roll)
		motion.halo(canvas, nozzle + Vector2(0, 16), 24.0, Color("ffba68"), .31)
		motion.sprite(canvas, exhaust, nozzle, 63.0 + sin(t * 25.0) * 3.0, Color.WHITE, roll)
	else:
		var chute = centre + Vector2(-sin(t * 2.6) * 30.0, -86.0 + sin(t * 3.2) * 3.5)
		var angle = -roll * .68
		for side in [-1.0, 1.0]:
			var harness = centre + Vector2(side * 12.0, -9.0).rotated(roll)
			for spread in [17.0, 50.0]:
				var seam = chute + Vector2(side * spread, 12.0).rotated(angle)
				canvas.draw_line(seam, harness, Color("30213e"), 2.3, true)
				canvas.draw_line(seam, harness, Color("c4a994"), .9, true)
		motion.sprite(canvas, "chute_" + str(e.kind).trim_prefix("para_"), chute, 142.0, Color.WHITE, angle)
	motion.sprite(canvas, pose, centre, 122.0, Color.WHITE, roll)

static func dialogue(g, e: Dictionary, centre: Vector2, age: float) -> void:
	var alarm_age = age - float(e.alert_at)
	if e.alert_at < 0.0 or alarm_age >= 1.65 or e.used_at >= 0.0: return
	var message = "Eles nunca me pegarão aqui!" if alarm_age < .87 else "Como vocês subiram?!"
	var pos = centre - Vector2(0, 84)
	var hud_edge: float = g.scenery.view_top + 170.0
	var beside = pos.y < hud_edge
	if beside: pos = Vector2(centre.x + 166.0, maxf(centre.y - 33.0, hud_edge))
	pos.x = clampf(pos.x, g.scenery.view_left + 140.0, g.scenery.view_right - 140.0)
	var body = Rect2(pos - Vector2(132, 21), Vector2(264, 39))
	var fill = Color("2d1e3d")
	g.panel(body, fill, Color("d1a978"), 11, 2)
	var anchor = pos + Vector2(0, 16)
	if beside: anchor = Vector2(pos.x - signf(pos.x - centre.x) * 130.0, pos.y)
	var half_stem = Vector2(0, 7) if beside else Vector2(7, 0)
	g.paint_target.draw_colored_polygon(PackedVector2Array([anchor - half_stem, anchor + half_stem, centre - Vector2(0, 41)]), fill)
	g.text(message, pos + Vector2(0, 4), 16, g.CREAM, true, true, 2)

static func paint_capture(canvas: Node2D, motion, kind: String, origin: Vector2, t: float, fade: float) -> void:
	var debris = "jet_short" if kind == JETPACK else "folded_" + kind.trim_prefix("para_")
	var fall = origin + Vector2(17.0 + 84.0 * t, -41.0 - 18.0 * t + 114.0 * t * t)
	motion.sprite(canvas, debris, fall, 85.0 - 24.0 * t, Color(1, .90, 1, fade), t * 1.45)
	motion.sprite(canvas, "catch_wisp", origin - Vector2(0, 38.0 * t), 82.0 + 58.0 * t, Color(1, 1, 1, fade))
	motion.burst_particles(canvas, origin, t, Color("e8adff"), 14, 105.0, .45)
