extends RefCounted
## Shared journey encounters. Neither journey is a purchasable power-up.
var random = RandomNumberGenerator.new()
var pending = false
var dock_world = 0.0
var next_at = 0.0
var offered = 0
var completed_count = 0
var last_kind = ""
var offered_kind = ""
var history: Array = []

func reset(seed_value: int) -> void:
	random.seed = seed_value^0x139d0c;pending = false;dock_world = 0;offered = 0;completed_count = 0
	last_kind = "";offered_kind = "";history.clear();next_at = random.randf_range(45,75)

func offer(r,forced: bool = false,event_kind: String = "sewer") -> bool:
	if pending or r.sewer.active or r.space.active or r.dead: return false
	if event_kind not in ["sewer","space"]: return false
	if not forced and (not r.power_eligible() or r.bonus_director.active(r) or r.inside_tunnel() or r.members.any(func(m):return m.falling)): return false
	if not forced and not r.terrain.safe_span(r.world_px+r.ANCHOR-180,r.world_px+r.ANCHOR+r.speed*1.3,45): return false
	if event_kind=="space":
		if not r.space.begin(r,forced): return false
		offered += 1;offered_kind = "space";last_kind = "space"
		history.append({"kind":"space","at":r.elapsed});return true
	pending = true;offered += 1;offered_kind = "sewer";last_kind = "sewer"
	dock_world = r.world_px+maxf(r.view_right+260,1450)
	r.sewer.reserve_ground(r,dock_world+r.generation_horizon()+2800)
	r.next_pattern_world = dock_world+r.generation_horizon()+2200
	r.entities = r.entities.filter(func(e):return e.kind in ["coin","civilian","police","soldier"] or e.x<r.ANCHOR-220)
	history.append({"kind":"sewer","at":r.elapsed})
	r.events.append({"type":"sewer_dock","x":dock_world-r.world_px});return true

func tick(r) -> void:
	if r.dead or r.sewer.active or r.space.active or not r.developer_kind.is_empty(): return
	if pending:
		if dock_world-r.world_px<=minf(r.sewer.LEAD,r.view_right-250):
			if r.sewer.begin(r,true): pending = false
		return
	if r.elapsed<next_at or r.world_px<2800 or r.tutorial_hints(): return
	if random.randf()>.68: next_at = r.elapsed+random.randf_range(12,24);return
	var kind = "space" if random.randf()<.5 else "sewer"
	if kind==last_kind: kind = "sewer" if kind=="space" else "space"
	if offer(r,false,kind): return
	next_at = r.elapsed+2.0

func complete(r,kind: String = "sewer") -> void:
	pending = false;offered_kind = "";last_kind = kind;completed_count += 1
	next_at = r.elapsed+random.randf_range(105,155)
