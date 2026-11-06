extends RefCounted
## Shared journey encounters. Neither journey is a purchasable power-up.
const FIRST_WINDOW = Vector2(55.0, 90.0)
const NEXT_WINDOW = Vector2(65.0, 105.0)
const RETURN_WINDOW = Vector2(135.0, 195.0)
const SEWER_CHANCE = .16
const SKY_CHANCE = .16
const BOTH_CHANCE = .05

var random = RandomNumberGenerator.new()
var pending = false
var sewer_armed = false
var dock_world = 0.0
var next_at = 0.0
var offered = 0
var completed_count = 0
var offered_kind = ""
var history: Array = []

func reset(seed_value: int) -> void:
	random.seed = seed_value ^ 0x139d0c
	pending = false
	sewer_armed = false
	dock_world = 0.0
	offered = 0
	completed_count = 0
	offered_kind = ""
	history.clear()
	next_at = random.randf_range(FIRST_WINDOW.x, FIRST_WINDOW.y)

static func roll_kind(roll: float) -> String:
	if roll < SEWER_CHANCE: return "sewer"
	if roll < SEWER_CHANCE + SKY_CHANCE: return "space"
	if roll < SEWER_CHANCE + SKY_CHANCE + BOTH_CHANCE: return "both"
	return ""

func offer(r,forced: bool = false,event_kind: String = "sewer") -> bool:
	if pending or r.sewer.active or r.space.active or r.sky.active or r.sky.pending or r.dead: return false
	if event_kind not in ["sewer", "space", "both"]: return false
	if not forced and (not r.power_eligible() or r.bonus_director.active(r) or r.inside_tunnel() or r.members.any(func(m):return m.falling)): return false
	if not forced and not r.terrain.safe_span(r.world_px+r.ANCHOR-180,r.world_px+r.ANCHOR+r.speed*1.3,45): return false
	var sewer_here = event_kind != "space"
	var sky_here = event_kind != "sewer"
	var dock = r.world_px + maxf(r.view_right + 260.0, 1450.0)
	var edge = dock - r.sewer.DOCK_TO_EDGE
	if sewer_here and not forced:
		if not r.safe_world_position(edge) or not r.terrain.safe_span(edge - 220.0, edge + 240.0, 45.0): return false
		if r.ground_y(edge - r.world_px) != r.FLOOR: return false
	if sky_here and not r.sky.offer(r, forced): return false
	offered += 1
	offered_kind = event_kind
	history.append({"kind": event_kind, "at": r.elapsed})
	if sewer_here:
		pending = true
		dock_world = dock
		r.sewer.visual.shaft.reset_cover()
		if forced and not sky_here: select_sewer(r)
	return true

func cutout_pending() -> bool:
	return pending and sewer_armed

func select_sewer(r) -> bool:
	if not pending or sewer_armed or r.dead or r.active_count() <= 0: return false
	sewer_armed = true
	r.sky.pending = false
	r.sewer.reserve_ground(r, dock_world + r.generation_horizon() + 2800.0)
	r.next_pattern_world = dock_world + r.generation_horizon() + 2200.0
	r.entities = r.entities.filter(func(e): return e.kind in ["coin", "civilian", "police", "soldier"] or e.x < r.ANCHOR - 220.0)
	r.events.append({"type": "sewer_dock", "x": dock_world - r.world_px})
	return true

func selected_sky() -> void:
	pending = false
	sewer_armed = false

func tick(r) -> void:
	if r.dead or r.sewer.active or r.space.active or r.sky.active or not r.developer_kind.is_empty(): return
	if pending:
		var distance = dock_world - r.world_px
		var entrance = minf(r.sewer.LEAD, r.view_right - 250.0)
		if sewer_armed:
			if distance <= entrance and r.sewer.begin(r, true):
				pending = false
				sewer_armed = false
		elif distance <= maxf(entrance - r.speed * .30, r.ANCHOR + r.sewer.DOCK_TO_EDGE + 125.0):
			pending = false
			skip(r)
		return
	if r.sky.pending: return
	if r.elapsed<next_at or r.world_px<2800 or r.tutorial_hints(): return
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
