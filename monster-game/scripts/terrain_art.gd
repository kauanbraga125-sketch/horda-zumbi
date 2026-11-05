class_name HordeTerrainArt
extends RefCounted

const SEWER_BANK_INSET = 128.0
const SEWER_BANK_PROFILE = [
	Vector2(0, 0), Vector2(-3, 8), Vector2(-12, 17), Vector2(-7, 25),
	Vector2(-25, 38), Vector2(-19, 49), Vector2(-38, 66), Vector2(-48, 87),
	Vector2(-40, 101), Vector2(-60, 123), Vector2(-57, 146), Vector2(-76, 171),
	Vector2(-72, 198), Vector2(-98, 230), Vector2(-92, 264), Vector2(-126, 321),
]
const SEWER_LIP_SOURCE = Rect2(207, 564, 209, 311)
const SEWER_LIP_SCALE = 0.365
const SEWER_CHIPS = [Rect2(1474, 382, 44, 49), Rect2(1610, 349, 58, 69), Rect2(1523, 346, 22, 33)]

static func cell(texture: Texture2D, index: int) -> Rect2:
	var x1 = roundf(index % 4 * texture.get_width() / 4.0)
	var x2 = roundf((index % 4 + 1) * texture.get_width() / 4.0)
	var y1 = roundf(int(index / 4) * texture.get_height() / 2.0)
	return Rect2(x1, y1, x2 - x1, texture.get_height() / 2.0)

static func pit_edge(g, edge: float, floor_y: float, right_bank: bool) -> void :
	var source = cell(g.art.terrain_parts, 5 if right_bank else 4)
	source.position += Vector2(94 if right_bank else 290, 118);source.size = Vector2(150, 314)
	g.paint_target.draw_texture_rect_region(g.art.terrain_parts, Rect2(edge - (12 if right_bank else 44), floor_y - 1, 55, 115), source)

static func sewer_bank_outline(left: float, edge: float, top: float, bottom: float) -> PackedVector2Array:
	var outer_left = minf(left, edge - SEWER_BANK_INSET)
	var outline = PackedVector2Array([Vector2(outer_left, top)])
	for point in SEWER_BANK_PROFILE:
		outline.append(Vector2(edge, top) + point)
	var end_y = maxf(bottom, top + SEWER_BANK_PROFILE[-1].y + 1)
	outline.append(Vector2(edge + SEWER_BANK_PROFILE[-1].x, end_y))
	outline.append(Vector2(outer_left, end_y))
	return outline

static func sewer_bank_piece(canvas: Node2D, dest: Rect2, outline: PackedVector2Array, texture: Texture2D = null, source: Rect2 = Rect2()) -> void:
	if dest.size.y <= 0: return
	var quad = PackedVector2Array([dest.position, Vector2(dest.end.x, dest.position.y), dest.end, Vector2(dest.position.x, dest.end.y)])
	for polygon in Geometry2D.intersect_polygons(quad, outline):
		if texture == null:
			canvas.draw_colored_polygon(polygon, Color("20172f"))
		else:
			var uvs = PackedVector2Array()
			for point in polygon:
				uvs.append((source.position + (point - dest.position) / dest.size * source.size) / texture.get_size())
			canvas.draw_polygon(polygon, PackedColorArray([Color.WHITE]), uvs, texture)

static func sewer_lip(g, edge: float, top: float) -> void:
	# The authored roots and broken stones overlap the original road texture.
	# Feather only the joins that sit inside the rock face.
	var texture: Texture2D = g.art.terrain_parts
	var size = SEWER_LIP_SOURCE.size * SEWER_LIP_SCALE
	var origin = Vector2(edge + 16.0 - size.x, top)
	if origin.x + size.x <= g.scenery.view_left or origin.x >= g.scenery.view_right: return
	var xs = [0.0, 0.4, 1.0]
	var ys = [0.0, 0.76, 1.0]
	for column in range(2):
		for row in range(2):
			var corners = [Vector2(xs[column], ys[row]), Vector2(xs[column + 1], ys[row]), Vector2(xs[column + 1], ys[row + 1]), Vector2(xs[column], ys[row + 1])]
			var points = PackedVector2Array()
			var uvs = PackedVector2Array()
			var colors = PackedColorArray()
			for uv in corners:
				points.append(origin + uv * size)
				uvs.append((SEWER_LIP_SOURCE.position + uv * SEWER_LIP_SOURCE.size) / texture.get_size())
				colors.append(Color(1, 1, 1, minf(uv.x / xs[1], 1) * minf((1 - uv.y) / (1 - ys[1]), 1)))
			g.paint_target.draw_polygon(points, colors, uvs, texture)

static func sewer_chip(g, index: int, point: Vector2, width: float, angle: float, alpha: float) -> void:
	var source: Rect2 = SEWER_CHIPS[index % SEWER_CHIPS.size()]
	var size = source.size * width / source.size.x
	g.paint_target.draw_set_transform(point, angle)
	g.paint_target.draw_texture_rect_region(g.art.terrain_parts, Rect2(-size * 0.5, size), source, Color(1, 1, 1, alpha))
	g.paint_target.draw_set_transform(Vector2.ZERO)

static func elevation(g, edge: float, floor_y: float, height: float, right_bank: bool) -> void :
	var source = cell(g.art.terrain_parts, 7 if right_bank else 6)
	source.position += Vector2(98 if right_bank else 15, 28);source.size = Vector2(333 if right_bank else 367, 401)
	var width = maxf(58, height * 0.72)
	g.paint_target.draw_texture_rect_region(g.art.terrain_parts, Rect2(edge - width * (0.67 if right_bank else 0.33), floor_y, width, height + 28), source)

static func collapse(g, e: Dictionary) -> void :
	var opened = bool(e.get("collapsed", false))
	var age = maxf(0, float(g.runner.elapsed) - float(e.get("collapse_at", g.runner.elapsed)))
	if opened and age > 1.0: return
	var frame = 3 if opened else (2 if e.get("armed", false) and float(e.get("collapse_left", 1)) < 0.34 else (1 if e.get("armed", false) or int(e.get("fracture_variant", 0)) != 0 else 0))
	var source = cell(g.art.terrain_parts, frame)
	source.position += Vector2(14, 161);source.size = Vector2(418, 270)
	var pieces = ceili(float(e.width) / 108.0)
	var unit = float(e.width) / pieces
	for i in range(pieces):
		var y = float(e.y) + (330 * age * age if opened else (sin(g.runner.elapsed * 65 + i * 1.7) * 4.0 if e.get("armed", false) else 0.0))
		var angle = sin(float(e.id) + i) * age * 0.55 if opened else 0.0
		g.paint_target.draw_set_transform(Vector2(float(e.x) + unit * (i + 0.5), y), angle)
		g.paint_target.draw_texture_rect_region(g.art.terrain_parts, Rect2( - unit * 0.5, -1, unit + 0.6, 72), source, Color(1, 1, 1, clampf((1.0 - age) / 0.4, 0, 1) if opened else 1.0))
	g.paint_target.draw_set_transform(Vector2.ZERO)
	if not opened and g.runner.tutorial_hints():
		var warning = g.CORAL if e.get("armed", false) else g.GOLD
		g.paint_target.draw_line(Vector2(e.x, e.y - 2), Vector2(e.x + e.width, e.y - 2), warning, 2, true)
		for edge in [e.x, e.x + e.width]:
			g.paint_target.draw_line(Vector2(edge, e.y - 10), Vector2(edge, e.y + 8), warning, 3, true)
		if e.x > HordeRun.ANCHOR: g.text("CHÃO CEDE!", Vector2(e.x + e.width * 0.5, e.y - 26), 16, warning, true, true, 3)
