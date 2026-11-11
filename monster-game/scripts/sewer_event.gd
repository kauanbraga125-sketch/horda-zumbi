extends RefCounted
## Journeys are physical branches of the road, never menu selections.
const FIRST_WINDOW = Vector2(55.0, 90.0)
const NEXT_WINDOW = Vector2(65.0, 105.0)
const RETURN_WINDOW = Vector2(135.0, 195.0)
const SEWER_CHANCE = .16
const SKY_CHANCE = .16
const BOTH_CHANCE = .05
const ROAD_THICKNESS = 180.0

var random = RandomNumberGenerator.new()
var pending = false
var sewer_armed = false
var dock_world = 0.0
var gap_width = 200.0
var next_at = 0.0
var offered = 0
var completed_count = 0
var offered_kind = ""
var route = ""
var history: Array = []

func reset(seed_value: int) -> void:
	random.seed = seed_value ^ 0x139d0c
	pending = false
	sewer_armed = false
	dock_world = 0.0
	gap_width = 200.0
	offered = 0
	completed_count = 0
	offered_kind = ""
	route = ""
	history.clear()
	next_at = random.randf_range(FIRST_WINDOW.x, FIRST_WINDOW.y)

static func roll_kind(roll: float) -> String:
	if roll < SEWER_CHANCE: return "sewer"
	if roll < SEWER_CHANCE + SKY_CHANCE: return "space"
	if roll < SEWER_CHANCE + SKY_CHANCE + BOTH_CHANCE: return "both"
	return ""

func offer(r, forced: bool = false, event_kind: String = "sewer") -> bool:
	if pending or r.sewer.active or r.space.active or r.sky.active or r.sky.pending or r.dead: return false
	if event_kind not in ["sewer", "space", "both"]: return false
	if not forced and (not r.power_eligible() or r.bonus_director.active(r) or r.inside_tunnel() or r.members.any(func(m): return m.falling)): return false
	var sewer_here = event_kind != "space"
	var sky_here = event_kind != "sewer"
	var width = clampf(r.speed * .60, 180.0, 320.0)
	var dock = r.world_px + maxf(r.view_right + 260.0, 1450.0)
	# The trampoline stands on solid road before the finite opening.
	var pad = r.world_px + r.ANCHOR + clampf(r.speed * 1.9, 560.0, 1000.0)
	if sky_here: dock = pad + r.sky.PAD_WIDTH * .5 + 26.0 + r.sewer.DOCK_TO_EDGE
	var edge = dock - r.sewer.DOCK_TO_EDGE
	if not forced:
		var start = minf(r.world_px + r.ANCHOR - 220.0, edge - 220.0)
		if not r.safe_world_position(edge) or not r.terrain.safe_span(start, edge + width + 260.0, 45.0): return false
		if r.ground_y(edge - r.world_px) != r.FLOOR: return false
	if sky_here and not r.sky.offer(r, forced): return false
	offered += 1
	offered_kind = event_kind
	route = ""
	history.append({"kind": event_kind, "at": r.elapsed})
	if sewer_here:
		pending = true
		sewer_armed = true
		dock_world = dock
		gap_width = width
		r.sewer.visual.shaft.reset_cover()
		r.sewer.reserve_ground(r, edge + width + r.generation_horizon() + 2800.0)
		r.next_pattern_world = edge + width + r.generation_horizon() + 2200.0
		r.entities = r.entities.filter(func(e): return e.x < r.ANCHOR - 220.0)
		r.rebuild_surfaces()
		r.events.append({"type": "sewer_dock", "x": edge - r.world_px})
	return true

func cutout_pending() -> bool:
	return pending

func left(r) -> float:
	return dock_world - r.sewer.DOCK_TO_EDGE - r.world_px

func right(r) -> float:
	return left(r) + gap_width

func contains(r, x: float) -> bool:
	return pending and x > left(r) and x < right(r)

func select_sewer(_r) -> bool:
	# Legacy replay API: arming an opening never starts the journey.
	return pending

func enter(r) -> bool:
	if not pending or r.dead: return false
	r.sky.pending = false
	if not r.sewer.begin(r, true): return false
	route = "sewer"
	if not history.is_empty(): history[-1].route = route
	pending = false
	sewer_armed = false
	return true

func selected_sky() -> void:
	route = "sky"
	if not history.is_empty(): history[-1].route = route
	pending = false
	sewer_armed = false

func tick(r) -> void:
	if r.dead or r.sewer.active or r.space.active or r.sky.active or not r.developer_kind.is_empty(): return
	if pending:
		if route.is_empty() and r.members.all(func(m): return not m.falling and float(m.x) > right(r) + 12.0):
			route = "street"
			if not history.is_empty(): history[-1].route = route
		# Keep the opening visible behind a successful jump until off screen.
		if right(r) < r.view_left - 100.0:
			pending = false
			sewer_armed = false
			skip(r)
		return
	if r.sky.pending: return
	if r.elapsed < next_at or r.world_px < 2800 or r.tutorial_hints(): return
	var kind = roll_kind(random.randf())
	if not kind.is_empty() and offer(r, false, kind): return
	skip(r)

func skip(r) -> void:
	if pending or r.sky.pending: return
	offered_kind = ""
	next_at = r.elapsed + random.randf_range(NEXT_WINDOW.x, NEXT_WINDOW.y)

func complete(r) -> void:
	pending = false
	sewer_armed = false
	offered_kind = ""
	completed_count += 1
	next_at = r.elapsed + random.randf_range(RETURN_WINDOW.x, RETURN_WINDOW.y)
