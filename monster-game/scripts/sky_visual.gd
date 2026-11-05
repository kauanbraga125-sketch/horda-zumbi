extends RefCounted

const BACKDROP = preload("res://assets/art/v153/sky.webp")
const ATLAS = preload("res://assets/art/v153/props.webp")
const Atmosphere = preload("res://scripts/sky_atmosphere.gd")
var motion = preload("res://scripts/sky_motion.gd").new()
# Sole positions in the atlas tile, including its transparent border.
const PAD_FEET = [Vector2(.15, .835), Vector2(.50, .962), Vector2(.86, .835)]
const PAD_BASE_START = .78
const VIOLET = Color("edb8ff")
const MINT = Color("a9f4ce")

var sprites: Dictionary = {}

func warm() -> void:
	if not sprites.is_empty():
		return
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/v153/sky_art.json"))
	for key in manifest.sprites:
		var a: Array = manifest.sprites[key].rect
		var tile = AtlasTexture.new()
		tile.atlas = ATLAS
		tile.filter_clip = true
		tile.region = Rect2(a[0], a[1], a[2], a[3])
		sprites[key] = tile
	motion.warm()

func paint_background(g, r) -> void:
	var s = r.sky
	var blend = smoothstep(100.0, 475.0, s.altitude)
	if blend <= 0.0:
		return
	var left: float = g.scenery.view_left
	var right: float = g.scenery.view_right
	var top: float = g.scenery.view_top
	var bottom = minf(g.scenery.view_bottom, 430.0)
	if bottom <= top:
		return
	var width = maxf(1920.0, right - left + 400.0)
	var image_left = (left + right - width) * .5 - minf(180.0, (r.world_px - s.start_world) * .038)
	var height = width * 1.5
	var image_top = minf(top - 30.0, 430.0 - height - g.camera_ground_shift / g.camera_zoom * .22)
	var bands: Array[float] = [top]
	for y in [175.0, 215.0, 255.0, 295.0, 335.0, 375.0, 405.0]:
		if y > top and y < bottom: bands.append(y)
	bands.append(bottom)
	var high_tint = Color.WHITE.lerp(Color("b3b7e4"), smoothstep(4600.0, 13000.0, s.altitude))
	var u0 = (left - image_left) / width
	var u1 = (right - image_left) / width
	for i in range(bands.size() - 1):
		var y0 = bands[i]
		var y1 = bands[i + 1]
		var a0 = blend * (1.0 - smoothstep(175.0, 430.0, y0))
		var a1 = blend * (1.0 - smoothstep(175.0, 430.0, y1))
		var v0 = clampf((y0 - image_top) / height, 0.0, 1.0)
		var v1 = clampf((y1 - image_top) / height, 0.0, 1.0)
		var quad = PackedVector2Array([Vector2(left, y0), Vector2(right, y0), Vector2(right, y1), Vector2(left, y1)])
		var uv = PackedVector2Array([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)])
		var tint = PackedColorArray([Color(high_tint, a0), Color(high_tint, a0), Color(high_tint, a1), Color(high_tint, a1)])
		g.paint_target.draw_polygon(quad, tint, uv, BACKDROP)
	# Faint motes closer than the painted clouds make the change in altitude legible.
	var wind = clampf(s.velocity / 750.0, -1.5, 1.2)
	var span = right - left
	for i in range(12):
		var x = left + fposmod(i * 241.7 - (r.world_px - s.start_world) * .54, span)
		var y = top + fposmod(i * 91.3 - top * .74 + s.age * 20.0, bottom - top)
		var alpha = blend * smoothstep(top, top + 40.0, y) * (1.0 - smoothstep(bottom - 42.0, bottom, y))
		var point = Vector2(x, y)
		g.paint_target.draw_line(point, point + Vector2(-5.0, 9.0 * wind), Color(.88, .76, 1, alpha * .17), 1.4, true)

	Atmosphere.paint(g, r, motion)

func launcher(g, r) -> void:
	var s = r.sky
	if not s.pending and not s.active: return
	var x = s.pad_world - r.world_px
	if x < g.scenery.view_left - s.PAD_WIDTH or x > g.scenery.view_right + s.PAD_WIDTH: return
	var floor_y: float = r.ground_y(x)
	if g.scenery.view_bottom < floor_y - 125.0: return
	var canvas: Node2D = g.paint_target
	var compression = 0.0
	if s.active and s.age < .24: compression = sin(s.age / .24 * PI) * 15.0
	# The near rim meets the jump plane. Only the upper part compresses on impact.
	var width = s.PAD_WIDTH + 8.0
	var left = x - width * .5
	var top = floor_y - s.PAD_HEIGHT - 40.0 + compression
	var base_top = floor_y - 3.0
	var base_height = 13.0
	for foot in PAD_FEET:
		var sole_y = base_top + base_height * inverse_lerp(PAD_BASE_START, 1.0, foot.y)
		var sole = Vector2(left + width * foot.x, sole_y + 1.5)
		canvas.draw_set_transform(sole, 0.0, Vector2(32.0, 4.8))
		canvas.draw_circle(Vector2.ZERO, 1.0, Color(.033, .022, .06, .24))
		canvas.draw_circle(Vector2.ZERO, .70, Color(.023, .012, .039, .38))
	canvas.draw_set_transform(Vector2.ZERO)
	var tile: Rect2 = sprites.pad.region
	var split = tile.size.y * PAD_BASE_START
	canvas.draw_texture_rect_region(ATLAS, Rect2(left, top, width, base_top - top), Rect2(tile.position, Vector2(tile.size.x, split)))
	canvas.draw_texture_rect_region(ATLAS, Rect2(left, base_top, width, base_height), Rect2(tile.position + Vector2(0, split), Vector2(tile.size.x, tile.size.y - split)))
	if not s.pending or x < r.ANCHOR - 12.0: return
	var cue = Vector2(x, floor_y - 159.0)
	var rect = Rect2(cue - Vector2(123.0, 29.0), Vector2(246.0, 49.0))
	var ready = x - r.ANCHOR < clampf(r.speed * .83, 225.0, 420.0)
	g.panel(rect, Color("301b43"), g.GOLD if ready else Color("b992c8"), 12, 2)
	g.text("PULE AGORA" if ready else "PULE PARA SUBIR", cue + Vector2(0, 4), 21, g.GOLD if ready else g.CREAM, true, true, 3)
	var arrow = cue + Vector2(0, 34.0 + sin(g.ui_time * 6.2) * 4.0)
	canvas.draw_polyline(PackedVector2Array([arrow + Vector2(-7, -4), arrow + Vector2(0, 3), arrow + Vector2(7, -4)]), MINT, 2.4, true)

func paint(g, r) -> void:
	var s = r.sky
	var canvas: Node2D = g.paint_target
	for e in s.objects:
		var point: Vector2 = s.object_point(r, e, s.age)
		if point.x < g.scenery.view_left - 142.0 or point.x > g.scenery.view_right + 142.0 or point.y < g.scenery.view_top - 205.0 or point.y > g.scenery.view_bottom + 135.0:
			continue
		motion.paint_prop(g, r, e, point, sprites)
	motion.paint_bursts(g, r)
	var order: Array = r.members.filter(func(m): return not m.falling)
	order.sort_custom(func(a, b): return float(a.y) < float(b.y) if not is_equal_approx(a.y, b.y) else float(a.x) < float(b.x))
	for m in order:
		var foot = Vector2(m.x, m.y)
		if foot.x < g.scenery.view_left - 70.0 or foot.x > g.scenery.view_right + 70.0: continue
		if s.altitude < 215.0:
			canvas.draw_set_transform(Vector2(foot.x, r.FLOOR + 4), 0.0, Vector2(22, 4))
			canvas.draw_circle(Vector2.ZERO, 1.0, Color(.03, .015, .05, .28 * (1.0 - s.altitude / 215.0)))
			canvas.draw_set_transform(Vector2.ZERO)
		var rank = int(m.formation_rank)
		if s.boost_left > 0.0 and rank < 8:
			var tail = Vector2(-18.0 - sin(s.age * 11.0 + rank) * 8.0, 36.0 + 90.0 * s.boost_left)
			var glow = Color(.67, .96, .85, s.boost_left * .8)
			canvas.draw_polyline(PackedVector2Array([foot - Vector2(7, 12), foot + tail * .56, foot + tail]), glow, 2.5, true)
		var kind = int(m.kind)
		var state = "rise" if s.velocity > 35.0 else "fall"
		var tint = Color("ffb1a9").lerp(Color.WHITE, 1.0 - s.hurt_left * .85)
		g.actor.paint(canvas, kind, foot, 112.0, float(m.run_phase), state, r.elapsed + rank * .06, 0.0, tint, false, 1.0, true, float(m.air_time), float(m.vy), r.cosmetics_for(m, kind))

func paint_landing(g, r) -> void:
	motion.paint_landing(g, r)

func hud(g, r) -> void:
	var s = r.sky
	var view: Rect2 = g.full_rect()
	var edge = view.position + Vector2(28, 20)
	var altitude_rect = Rect2(edge, Vector2(176, 76))
	var charges_rect = Rect2(edge + Vector2(188, 0), Vector2(249, 76))
	var horde_rect = Rect2(edge + Vector2(449, 0), Vector2(143, 76))
	var peak_rect = Rect2(view.end.x - 280, edge.y, 164, 76)
	var pause_rect = Rect2(view.end.x - 100, edge.y, 72, 76)
	for rect in [altitude_rect, charges_rect, horde_rect, peak_rect]:
		g.home_menu.slab(g, rect, Color("251932"), Color("af8ea8"), 12, 3)
	g.home_menu.label(g, "ALTURA", altitude_rect.position + Vector2(15, 23), 15, g.MINT, false)
	g.home_menu.label(g, "%d m" % int(s.altitude / 30.0), altitude_rect.position + Vector2(15, 60), 31, g.CREAM, false)
	g.home_menu.label(g, "BRASAS DE ALMA", charges_rect.position + Vector2(15, 23), 15, VIOLET, false)
	for i in range(s.MAX_CHARGES):
		var pos = charges_rect.position + Vector2(29.0 + 35.0 * i, 52)
		g.scenery.sprite(g, sprites.ember, pos, 35.0, Color.WHITE if i < s.charges else Color(.55, .41, .66, .31))
	g.home_menu.label(g, str(s.charges), charges_rect.position + Vector2(214, 61), 25, g.CREAM, false)
	g.home_menu.label(g, "HORDA", horde_rect.position + Vector2(15, 23), 15, g.MINT, false)
	g.home_menu.label(g, str(r.active_count()), horde_rect.position + Vector2(15, 60), 31, g.CORAL if s.hurt_left > 0.0 else g.CREAM, false)
	g.home_menu.label(g, "PICO", peak_rect.position + Vector2(15, 23), 15, g.MINT, false)
	g.home_menu.label(g, "%d m" % int(s.peak / 30.0), peak_rect.position + Vector2(15, 60), 31, g.GOLD, false)
	g.home_menu.slab(g, pause_rect, Color("493053"), Color("bd915b"), 12, 4)
	g.gameplay_ui.glyph(g, "pause", pause_rect.get_center(), 40, g.CREAM)
	g.home_menu.register(g, pause_rect, "pause")
	var metres = int(s.altitude / 30.0)
	var region = "CÉU PROFUNDO" if metres >= 300 else ("VENTOS MALDITOS" if metres >= 120 else "BRUMA DO CEMITÉRIO")
	g.home_menu.label(g, region, edge + Vector2(4, 103), 17, Color("c3a4e3"), false)
	var message = "TOQUE PARA SUBIR"
	var colour = g.CREAM
	if s.charges <= 0:
		message = "SEM BRASAS • BUSQUE UM APOIO"
		colour = VIOLET
	elif s.velocity < -340.0:
		message = "TOQUE PARA RECUPERAR ALTURA"
	if s.notice_left > 0.0:
		message = s.notice
		colour = g.CORAL if s.hurt_left > 0.0 else g.MINT
	var hint = Vector2(view.get_center().x, edge.y + 117.0)
	g.text(message, hint, 21, colour, true, true, 3)
