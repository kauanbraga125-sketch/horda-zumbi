class_name HordeRun
extends RefCounted

const FLOOR = 574.0
const GRAVITY = HordeBalance.GRAVITY
const ANCHOR = MonsterCatalog.ANCHOR
const SEGMENT = 3300.0
const ZONE_LENGTH = MonsterCatalog.ZONE_LENGTH
const MAX_HORDE = MonsterCatalog.MAX_HORDE
var physics_surfaces: Array[Dictionary] = []
var physics_gaps: Array[Dictionary] = []
var last_soldier_world = 0.0
var cached_active = -1
var jump_delay_step = HordeTuning.FOLLOWER_DELAY_STEP
var jump_buffer_until = -1.0
var tutorial_enabled = false
var power_warning_tick = 4
var boost_warning_tick = 4
var surge_left = 0.0
var next_surge_at = 22.0
var surge_warning_left = 0.0
var shot_serial = 0
var rng = RandomNumberGenerator.new()
var course_rng = RandomNumberGenerator.new()
var reward_rng = RandomNumberGenerator.new()
var run_seed = 0
var bonus_director = HordeBonusDirector.new()
var space = preload("res://scripts/space.gd").new()
var sewer = preload("res://scripts/sewer.gd").new()
var bird = preload("res://scripts/bird_run.gd").new()
var blessings = preload("res://scripts/field_powers.gd").new()
var coin_rows: Dictionary = {}
var next_coin_row = 0
var jump_buffer_hold = -1.0
var jump_buffer_pressed_at = -1.0
var course_history: Array[String] = []
var generation_trace: Array[Dictionary] = []
var next_challenge_level = 0
var next_helicopter_world = 0.0
var mobile_slots = 0
var helicopter_draws = 0
var sequence_rejections = 0
var next_rhythm_world = 0.0

var view_left = 0.0
var view_right = 1600.0
var planning_right = 1600.0
var generation_started = false
var coin_credit = 0.0
var coin_budget_to = 0.0
var developer_kind = ""
var developer_stage = 0
var developer_iteration = 0
var vehicle_drought: Dictionary = {}
var last_heavy_challenge = -100000.0
var levels = {}
var route: Array[int] = [0, 1]
var members: Array[Dictionary] = []
var entities: Array[Dictionary] = []
var events: Array[Dictionary] = []
var elapsed = 0.0
var world_px = 0.0
var speed = 275.0
var pressure = 0.0
var recovery_left = 0.0
var recovery_speed = 275.0
var loss_times: Array[float] = []
var next_member_id = 0
var coins = 0
var recruits = 0
var souls = 0
var soldiers = 0
var rescues = 0
var groups = 0
var group_captures: Dictionary = {}
var next_entity_id = 0
var tunnels: Array[Dictionary] = []
var entered_tunnels = 0
var completed_tunnels = 0
var cars = 0
var mission_stats: Dictionary = {}
var last_loss_world = 0.0
var losses = 0
var shots = 0
var clean_jumps = 0
var bonuses = 0
var flights = 0
var boost_px = 0.0
var max_horde = 1
var shields = 0
var perk_kind = -1
var perk_left = 0.0
var boost_left = 0.0
var next_segment = 0
var last_variant = -1
var dead = false
var hit_grace = 0.0
var jumped = false
var clean_air = false
var last_area = 0
var last_tunnel = 0
var owned: Array = [0]
var power_owned: Array = [3]
var power_levels: Dictionary = {}
var transform_left = 0.0
var transform_kind = -1
var transform_from_kind = -1
var transform_duration = 2.8
var revive_charges = 0
var next_pattern_world = 2400.0
var pattern_index = 0
var last_gap_world = 0.0
var voice_cooldown = 0.0
var cruise_speed = 305.0
var last_effective_speed = 305.0
var time_scale = 1.0
var next_power_tunnel = 1
var last_three_world = -100000.0
var speech_text = ""
var speech_left = 0.0
var speech_npc = 0
var speech_cooldown = 0.0
var jump_sequence = 0
var wave_holds: Dictionary = {}
var npc_serial = 0
var next_rush_world = 0.0
var course_deck: Array[String] = []
var course_deck_advanced = false
var last_course_pattern = ""
var course_category_streak = 0
var last_course_obstacle = -100000.0
var course_unplaced = 0
var terrain = HordeTerrain.new()
var wave_durations: Dictionary = {}
var wave_started: Dictionary = {}
var last_coin_group = -100000.0
var coin_groups: Array[Dictionary] = []
var recent_phrases: Array[String] = []
var soldier = HordeSoldier.new()
var run_items: Dictionary = {}
var rare_pending = false
var opening_power = -1
var eyes_collected = 0
var loss_causes: Dictionary = {}
var active_cosmetics: Array = []

func start(upgrades: Dictionary, seed_value: int = 0, skin: int = 0, areas: Array = [0, 1], collection: Array = [0], powers: Array = [3], power_upgrades: Dictionary = {}) -> void :
	mission_stats.clear();last_loss_world=0.0
	run_items.clear();rare_pending = false;opening_power = -1;eyes_collected = 0;loss_causes.clear()
	levels = upgrades.duplicate(true)
	levels.jump = 0;levels.magnet = 0
	blessings.reset();coin_rows.clear();next_coin_row = 0;jump_buffer_hold = -1;jump_buffer_pressed_at = -1
	owned = collection.duplicate();power_owned = powers.duplicate();power_levels = power_upgrades.duplicate(true)
	route.assign([0, 1])
	for area in areas:
		if int(area) in [2, 3] and int(area) not in route: route.append(int(area))
	run_seed = seed_value if seed_value else Time.get_ticks_usec()
	rng.seed = run_seed;course_rng.seed = run_seed ^ 3699770;reward_rng.seed = run_seed ^ 5556785
	bonus_director.reset(run_seed)
	space.reset(run_seed)
	sewer.reset(run_seed);bird.configure(preload("res://scripts/bird_catalog.gd").defaults())
	course_history.clear();generation_trace.clear();next_challenge_level = 0;next_helicopter_world = 0
	mobile_slots = 0;helicopter_draws = 0;sequence_rejections = 0;next_rhythm_world = 0
	members.clear();entities.clear();events.clear();loss_times.clear();tunnels.clear();group_captures.clear()
	generation_started = false;coin_credit = 0;coin_budget_to = 0;developer_kind = "";developer_iteration = 0;vehicle_drought.clear();last_heavy_challenge = -100000
	physics_surfaces.clear();physics_gaps.clear();last_soldier_world = 0;cached_active = -1;power_warning_tick = 4;boost_warning_tick = 4;surge_left = 0;next_surge_at = 22;surge_warning_left = 0;shot_serial = 0
	elapsed = 0;world_px = 0;coins = 0;recruits = 0;cars = 0;losses = 0;shots = 0;clean_jumps = 0;bonuses = 0;flights = 0;boost_px = 0
	shields = 0;perk_kind = -1;perk_left = 0;boost_left = 0;next_segment = 0;last_variant = -1
	dead = false;hit_grace = 0;jumped = false;clean_air = false;speed = 305;pressure = 0;recovery_left = 0;recovery_speed = 275
	transform_left = 0;transform_kind = -1;revive_charges = 0;next_pattern_world = 2400;pattern_index = 0;last_gap_world = 0;voice_cooldown = 0
	max_horde = 1;next_member_id = 0;next_entity_id = 0;last_area = 0;last_tunnel = 0
	cruise_speed = 305;last_effective_speed = 305;time_scale = 1;next_power_tunnel = 1;last_three_world = -100000
	speech_text = "";speech_left = 0;speech_npc = 0;speech_cooldown = 0
	jump_sequence = 0;jump_buffer_until = -1.0;tutorial_enabled = false;wave_holds.clear();wave_durations.clear();wave_started.clear();npc_serial = 0;next_rush_world = 0
	course_deck.clear();course_deck_advanced = false;last_course_pattern = "";course_category_streak = 0;last_course_obstacle = -100000;course_unplaced = 0
	last_coin_group = -100000;coin_groups.clear();recent_phrases.clear();terrain.reset()
	souls = 0;soldiers = 0;rescues = 0;groups = 0;entered_tunnels = 0;completed_tunnels = 0
	schedule_tunnel(1, HordeTuning.TUNNEL_DISTANCE)
	terrain.reserve(self, 9000, 305)
	for i in range(1 + int(levels.get("horde", 0))): add_member(0 if i == 0 else recruit_kind(), false)
	spawn_segment(0)
	next_segment = 1;generation_started = true
	for e in entities:
		if e.kind == "coin": coin_credit -= 1

func slot_x(index: int) -> float:
	var columns = 10 if members.size() > 24 else 8
	var spacing = 52.0 if members.size() <= 6 else (26.0 if columns == 10 else 35.0)
	var rank = int(members[index].get("formation_rank", index)) if index < members.size() else index
	# Keep every column distinct even when the camera zooms in.
	var rows = int(maxi(0, members.size() - 1) / columns)
	var available_width = maxf(180.0, ANCHOR - view_left - rows * 15.0 - 12.0)
	spacing = minf(spacing, available_width / float(mini(columns - 1, maxi(1, members.size() - 1))))
	return ANCHOR - float(rank % columns) * spacing - float(int(rank / columns)) * 15.0

func member_lane(index: int) -> int:
	var columns = 10 if members.size() > 24 else 8
	var rank = int(members[index].get("formation_rank", index)) if index < members.size() else index
	return int(rank / columns)

func member_depth(_index: int) -> float:
	# Lanes control crowd ordering, never lift grounded feet off the surface.
	return 0.0

func member_x(index: int) -> float:
	return float(members[index].x) if index >= 0 and index < members.size() else slot_x(index)

func cosmetics_for(m: Dictionary, kind: int) -> Array:
	if kind not in [0, 1]: return []
	var key = "cosmetics_" + str(kind)
	if not m.has(key): m[key] = HordeCosmetics.choose(run_seed, int(m.id), kind, active_cosmetics)
	return m[key]

func active_count() -> int:
	if cached_active >= 0: return cached_active
	var total = 0
	for m in members:
		if not m.falling: total += 1
	cached_active = total
	return total

func leader_index() -> int:
	var lead = -1
	for i in range(members.size()):
		if not members[i].falling and (lead < 0 or float(members[i].x) > float(members[lead].x)): lead = i
	return lead

func refresh_formation() -> void:
	var order: Array = members.filter(func(m): return not m.falling)
	order.sort_custom(func(a, b): return int(a.get("formation_rank", a.id)) < int(b.get("formation_rank", b.id)))
	# A member ahead of a blocked neighbour can take its slot. Hysteresis
	# prevents small animation/physics corrections from shuffling the group.
	for i in range(1, order.size()):
		var j = i
		while j > 0 and float(order[j].x) > float(order[j - 1].x) + 12.0:
			var previous = order[j - 1];order[j - 1] = order[j];order[j] = previous;j -= 1
	for i in range(order.size()): order[i].formation_rank = i

func separate_members(dt: float) -> void:
	# Adjacent neighbours per lane, instead of every pair testing every vehicle.
	var lanes: Dictionary = {}
	var minimum = 38.0 if members.size() <= 6 else 24.0 if members.size() > 24 else 30.0
	for i in range(members.size()):
		if members[i].falling: continue
		var lane = member_lane(i)
		if not lanes.has(lane): lanes[lane] = []
		lanes[lane].append(members[i])
	for lane in lanes:
		var order: Array = lanes[lane]
		order.sort_custom(func(a,b): return float(a.x)<float(b.x))
		for i in range(1,order.size()):
			var a: Dictionary = order[i-1];var b: Dictionary = order[i]
			var dy = float(a.y)-float(b.y)
			if absf(dy)>=minimum: continue
			var required = sqrt(minimum*minimum-dy*dy)
			var overlap = required-(float(b.x)-float(a.x))
			if overlap<=0: continue
			var correction = minf(overlap,dt*HordeTuning.REFORM_WALK_SPEED)*.5
			a.x = reform_x(a,float(a.x)-correction,dt)
			b.x = reform_x(b,float(b.x)+correction,dt)

func add_member(kind: int, count_recruit: bool = true, spawn: Vector2 = Vector2(INF, INF)) -> void :
	if dead or ( not members.is_empty() and active_count() == 0): return
	if members.size() >= MAX_HORDE:
		coins += 2;events.append({"type": "coin", "amount": 2, "x": ANCHOR, "y": FLOOR - 70})
		return
	var index = members.size()
	members.append({"id": next_member_id, "kind": clampi(kind, 0, 3), "x": slot_x(index) if is_inf(spawn.x) else spawn.x, "y": ground_y(slot_x(index)) if is_inf(spawn.y) else minf(FLOOR, spawn.y), "vy": 0.0, "jump_delay": -1.0, "jump_at": -1.0, 
		"hurt_left": 0.0, "mask_flip_left": 0.0, "mask_push_at": 0.0, "landed_at": -1.0, "last_jump_at": -1.0, "air_jumps": 0, "coyote": 0.1, "land_left": 0.0, "glide_left": 0.0, "arrival": 0.0, "step_phase": -1, "falling": false, "attack_left": 0.0, "push_left": 0.0, "run_phase": index * 0.11, "air_pose": 0.0, "jump_ground_only": false, "jump_queue": [], "wave_id": -1, "air_time": 0.0, "roof_id": -1, "reform_hold_until": 0.0, "jump_gravity_scale": 1.0, "formation_rank": index})
	cached_active = -1
	next_member_id += 1;max_horde = maxi(max_horde, active_count())
	if count_recruit:
		recruits += 1;events.append({"type": "recruit", "x": slot_x(index), "y": FLOOR - 50})

func add_entity(kind: String, x: float, y: float = FLOOR, variant: int = 0, width: float = 70, power_delivery: bool = false) -> Dictionary:

	if kind == "recruit": kind = "civilian"
	if y == FLOOR and (MonsterCatalog.VEHICLES.has(kind) or kind in ["civilian", "police", "soldier", "bomb", "crate", "spikes"]): y = ground_y(x)
	var entity = {"id": next_entity_id, "kind": kind, "x": x, "y": y, "base_y": y, "variant": variant, "width": width, "taken": false, 
		"vx": -70.0 if kind == "helicopter" else (-190.0 if kind == "bullet" else (-40.0 if kind == "air_bomb" else 0.0)), 
		"timer": rng.randf_range(1.2, 1.8), "flash": 0.0, "bob": rng.randf_range(0, TAU), "state": "normal", "age": 0.0, "vy": 0.0, 
		"pose": "run", "contacts": {}, "push_age": 0.0, "tilt": 0.0, "passengers": [], "group": -1, "rescued": false, "speech_left": 0.0, "spoke": false, "rushing": false, "warned": false, "voice_wait": rng.randf_range(0.2, 1.5), "speech": "", "damage_stage": 0}
	next_entity_id += 1
	if kind in ["civilian", "soldier", "police"]:
		npc_serial += 1;entity.speaker = npc_serial % 3 == 0
		var phrases = MonsterCatalog.CIVIL_PHRASES if kind == "civilian" else (MonsterCatalog.POLICE_PHRASES if kind == "police" else MonsterCatalog.ARMY_PHRASES)
		entity.speech = phrases[rng.randi_range(0, phrases.size() - 1)]
	if kind == "soldier": entity.timer = rng.randf_range(0.45, 0.65)
	if kind == "police": entity.vx = -135;entity.pose = "police_run"
	if kind == "civilian":
		entity.variant = clampi(variant, 0, 2);entity.vx = rng.randf_range(-55, 90)
		entity.pose = ["run", "hop", "panic"][rng.randi_range(0, 2)]
		if int(entity.variant) == 2:
			entity.worker_clip = "desastrado";entity.worker_time = fposmod(float(entity.bob), 3.84)
			entity.vx = 0.0;entity.pose = "idle"
		if int(entity.variant) == 1:
			entity.woman_clip = "idle";entity.woman_time = rng.randf_range(0.0, 1.0)
			entity.flee_speed = rng.randf_range(70.0, 98.0)
			entity.vx = 0.0;entity.pose = "idle"
		if MonsterCatalog.CIVILIANS[entity.variant].get("key", "") == "civil_casaco_azul_nerd":
			entity.civil_key = "civil_casaco_azul_nerd";entity.civil_clip = "parado_nervoso";entity.civil_time = rng.randf_range(0, 3.2)
			entity.civil_flip = true;entity.civil_previous_flip = true;entity.civil_turn_left = 0.0
			entity.flee_speed = rng.randf_range(65, 95);entity.vx = 0.0;entity.pose = "idle"
	if MonsterCatalog.VEHICLES.has(kind):
		var spec = MonsterCatalog.VEHICLES[kind]
		entity.merge(HordeBalance.vehicle_geometry(spec, maxf(305, speed)), true)

		entity.required_count = int(spec.need);entity.reinforced = false
		var passenger_count = 0
		if variant == -89: entity.rushing = true;entity.variant = 0
		else:
			var available = remaining_soul_slots()
			if available < int(spec.rescue_min): entity.taken = true;return entity
			passenger_count = rng.randi_range(int(spec.rescue_min), mini(int(spec.rescues), available))
		for i in range(passenger_count): entity.passengers.append(rng.randi_range(0, 2))
	if kind in ["civilian", "soldier", "police"] and not power_delivery and remaining_soul_slots() <= 0:
		entity.taken = true;return entity
	entity.budgeted_coin = kind == "coin" and generation_started and developer_kind.is_empty()
	if entity.budgeted_coin: coin_credit -= 1
	entity.created_x = x;entity.created_right = planning_right;entity.created_world = world_px
	entities.append(entity)
	if MonsterCatalog.VEHICLES.has(kind) or kind == "helicopter": physics_surfaces.append(entity)
	if kind in ["gap", "collapse"]: physics_gaps.append(entity)
	if not HordeCourse.hazard_rect(self, entity).size == Vector2.ZERO: invalidate_coins()
	return entity

func coin_arc(base: float, _count: int = 7, _height: float = 125, _spacing: float = 72) -> void :
	HordeCourse.create_formation(self, world_px + base, maxf(305, speed), pattern_index)

func fund_coins(through: float, road_speed: float) -> void :
	if through <= coin_budget_to: return
	coin_credit = minf(HordeTuning.COIN_CREDIT_LIMIT, coin_credit + (through - coin_budget_to) / maxf(305, road_speed) * HordeTuning.COINS_PER_ROAD_SECOND)
	coin_budget_to = through

func can_fund_coins(count: int) -> bool:
	return not generation_started or not developer_kind.is_empty() or coin_credit + 0.001 >= count

func spawn_left() -> float:
	return world_px + maxf(view_right, planning_right) + 180

func generation_horizon() -> float:
	return maxf(view_right, planning_right) + maxf(1000, speed * 3.0)

func member_floor(m: Dictionary) -> Dictionary:
	var result = {"y": ground_y(m.x), "solid": has_floor(m.x), "roof": -1}
	for e in physics_surfaces:

		if e.taken and elapsed > float(e.get("roof_hold_until", -1.0)): continue
		var body = HordeBalance.surface(e)
		var roof = body.position.y
		if float(m.x) < body.position.x or float(m.x) > body.end.x: continue
		if float(m.y) <= roof + 12.0 and roof < float(result.y):
			result = {"y": roof, "solid": true, "roof": int(e.id)}
	return result

func reform_x(m: Dictionary, target: float, dt: float) -> float:

	if float(m.get("reform_hold_until", 0.0)) > elapsed: return float(m.x)
	var airborne = float(m.y) < float(m.get("surface_y", ground_y(float(m.x)))) - 4.0
	var candidate: = move_toward(float(m.x), target, dt * (HordeTuning.REFORM_AIR_SPEED if airborne else HordeTuning.REFORM_WALK_SPEED))
	if not airborne:
		# Never slide a grounded character into a hole or through a step.
		if not has_floor(candidate) or ground_y(candidate) < float(m.y) - 3.0: return float(m.x)
	for e in entities:
		if e.taken or not MonsterCatalog.VEHICLES.has(e.kind): continue

		if absf(float(e.x) - float(m.x)) > float(e.width) * 0.5 + 90.0: continue
		var roof: = float(e.y) - float(e.roof)
		if float(m.y) <= roof + 14: continue
		var edge: = float(e.x) - float(e.width) * 0.5 - 21.0
		var end: = float(e.x) + float(e.width) * 0.5 + 12.0
		if maxf(float(m.x), candidate) >= edge and minf(float(m.x), candidate) <= end:
			if candidate < float(m.x) and float(m.x) >= end: candidate = maxf(candidate, end)
			elif candidate > float(m.x) and float(m.x) <= edge: candidate = minf(candidate, edge)
	for gap in physics_gaps:
		if float(m.x) < float(gap.x) - 12.0 or float(m.x) > float(gap.x) + float(gap.width) + 12.0: continue
		if gap.kind not in ["gap", "collapse"]: continue
		if gap.kind == "collapse" and not gap.get("collapsed", false): continue
		if float(m.y) < ground_y(float(m.x)) - 12: continue
		if candidate > float(gap.x) and candidate < float(gap.x) + float(gap.width):
			return float(m.x)
	return candidate

func start_developer(kind: String, count: int, stage: int, seed_value: int = 0) -> void :
	start({}, seed_value)
	developer_kind = kind;developer_stage = stage;developer_iteration = 0
	entities.clear();physics_surfaces.clear();physics_gaps.clear();events.clear();tunnels.clear();course_history.clear();generation_trace.clear()
	terrain.reset();terrain.generated_to = 1000000000;terrain.segments[0].end = terrain.generated_to
	entered_tunnels = stage;completed_tunnels = stage;next_pattern_world = planning_right + 400
	speed = HordeDirector.stage_speed(stage);cruise_speed = speed;last_effective_speed = speed
	while members.size() < count: add_member(0, false)
	pressure = HordeDirector.profile(0, count, 0, 0, stage).pressure_target

func update_collapses(dt: float) -> void :
	for e in entities:
		if e.kind != "collapse" or e.taken or e.get("collapsed", false): continue
		if not e.get("armed", false) and e.x - ANCHOR <= speed * HordeTuning.COLLAPSE_WARNING_SECONDS:
			e.armed = true;e.collapse_left = HordeTuning.COLLAPSE_WARNING_SECONDS - 0.06
			events.append({"type": "collapse_warning", "x": e.x, "y": e.y - 20})
		if e.get("armed", false):
			e.collapse_left -= dt
			if e.collapse_left <= 0:
				e.collapsed = true;e.collapse_at = elapsed;events.append({"type": "collapse", "x": e.x + e.width * 0.5, "y": e.y})

func ground_y(x: float) -> float:
	return terrain.floor_at(world_px + x)

func invalidate_coins() -> void :
	for e in entities:
		if e.kind == "coin" and not e.taken and e.x > maxf(view_right, planning_right) + 80 and not HordeCourse.coin_clear(self, Vector2(world_px + e.x, e.y), false):
			e.taken = true
			miss_coin_row(e)
			if e.get("budgeted_coin", false): coin_credit = minf(HordeTuning.COIN_CREDIT_LIMIT, coin_credit + 1)

func moving_lane_safe(x: float, distance: float) -> bool:
	var left = minf(ANCHOR - 100, x - distance)
	if not terrain.safe_span(world_px + left, world_px + x + 220, 100): return false
	for e in entities:
		if e.taken: continue
		if e.get("rushing", false): return false
		if e.kind == "gap" and e.x < x + 180 and e.x + e.width > left: return false
		var box = HordeCourse.hazard_rect(self, e)
		if box.size != Vector2.ZERO and box.intersects(Rect2(world_px + left, ground_y(x) - 135, x - left + 220, 135)): return false
	return true

func tunnel_number() -> int:
	return developer_stage if not developer_kind.is_empty() else entered_tunnels

func area() -> int:
	return route[posmod(completed_tunnels, route.size())]

func tunnel_phase() -> float:
	var tunnel = current_tunnel()
	return world_px - float(tunnel.entry) if not tunnel.is_empty() else -1

func inside_tunnel() -> bool:
	for t in tunnels:
		if world_px >= float(t.entry) and world_px < float(t.entry) + float(t.length): return true
	return false

func safe_world_position(x: float) -> bool:
	for t in tunnels:
		if x >= float(t.entry) + ANCHOR - 550 and x <= float(t.entry) + ANCHOR + float(t.length) + 850: return false
	return true

func safe_reward_position(x: float) -> bool:
	for t in tunnels:
		for edge in [float(t.entry) + ANCHOR, float(t.entry) + ANCHOR + float(t.length)]:
			if absf(x - edge) < 180: return false
	return true

func record_chunk(kind: String, start_world: float, end_world: float, commands: Array[Dictionary] = []) -> void :
	course_history.append(kind)
	while course_history.size() > HordeTuning.HISTORY_LENGTH: course_history.pop_front()
	generation_trace.append({"seed": run_seed, "chunk": pattern_index, "kind": kind, "tunnel": tunnel_number(), "speed": snappedf(speed, 0.01), "horde": active_count(), "pressure": snappedf(pressure, 0.01), "start": start_world, "end": end_world, "commands": commands.duplicate(true)})
	while generation_trace.size() > HordeTuning.TRACE_LENGTH: generation_trace.pop_front()

func save_generation_trace() -> void :
	var file = FileAccess.open("user://last_run_generation.json", FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"version": "0.8.10", "seed": run_seed, "tunnel": tunnel_number(), "world": world_px, "chunks": generation_trace}, "  "))

func spawn_segment(index: int) -> void :
	if index == 0:
		spawn_civilians(1050 - world_px, 1, 0)
		HordeCourse.create_formation(self, 850, 305, 0)
	else: HordeCourse.build(self, float(index) * SEGMENT, index)

func spawn_next_pattern() -> void :
	var absolute = maxf(next_pattern_world + ANCHOR, spawn_left() + 100)
	if not safe_world_position(absolute):
		for t in tunnels:
			if absolute >= float(t.entry) + ANCHOR - 550 and absolute <= float(t.entry) + ANCHOR + float(t.length) + 850:
				HordeCourse.fill_breathing(self, absolute, float(t.entry) + ANCHOR + float(t.length) + 850, maxf(305, cruise_speed), pattern_index)
				next_pattern_world = float(t.entry) + float(t.length) + 900
				return
	var finish_world = HordeCourse.build(self, absolute, pattern_index)
	next_pattern_world = finish_world - ANCHOR;pattern_index += 1;next_segment = pattern_index + 1

func has_floor(x: float) -> bool:
	if boost_protected(): return true
	if inside_tunnel(): return true
	for e in physics_gaps:
		if e.kind in ["gap", "collapse"] and (e.kind == "gap" or e.get("collapsed", false)) and x > e.x and x < e.x + e.width: return false
	return true

func grounded_strength() -> int:
	var count = 0
	for m in members:
		if not m.falling and m.y >= ground_y(m.x) - 12 and m.y <= ground_y(m.x) + 2 and has_floor(m.x): count += 1
	return count

func jump() -> void :
	if sewer.active: sewer.request_jump(self);return
	if space.active: space.impulse();return
	HordeJump.request(self)

func release_jump() -> void :
	if jump_buffer_until >= elapsed and jump_buffer_pressed_at >= 0 and jump_buffer_hold < 0: jump_buffer_hold = maxf(HordeTuning.MIN_TAP_HOLD,elapsed-jump_buffer_pressed_at)
	if bool(wave_holds.get(jump_sequence, false)):
		wave_durations[jump_sequence] = clampf(elapsed - float(wave_started.get(jump_sequence, elapsed)), 0, HordeBalance.MAX_HOLD)
	wave_holds[jump_sequence] = false

func grant_perk(kind: int) -> void :
	if kind in [5,6]:
		if not dead and not space.active and kind in power_owned:
			blessings.begin(self,kind);mark_power_collected();bonuses += 1
		return
	var lead = leader_index()
	if dead or space.active or lead < 0 or transform_left > 0 or kind not in power_owned: return
	transform_from_kind = perk_kind if perk_left > 0 else -1
	transform_kind = kind;transform_left = transform_duration
	mark_power_collected()
	bonuses += 1
	events.append({"type": "transform", "kind": kind, "x": members[lead].x, "y": members[lead].y - 60})

func activate_perk(kind: int) -> void :
	perk_kind = kind
	power_warning_tick = 4
	perk_left = (15.0 if run_items.has("bonus_time") else 0.0) + HordeTuning.BASE_POWER_SECONDS + int(levels.get("perk", 0)) * 2 + int(power_levels.get("fly_time" if kind == 3 else "mask_time", 0)) * 3
	revive_charges = 1 if kind == 2 and int(power_levels.get("mask_revive", 0)) > 0 else 0
	if kind == 2 and int(power_levels.get("mask_shield", 0)) > 0: shields = maxi(shields, 3)
	if kind == 3:
		flights += 1
		for m in members:
			if not m.falling: m.jump_delay = -1;m.jump_at = -1;m.vy = minf(m.vy, -180)
	events.append({"type": "perk", "kind": kind})

func recruit_kind() -> int:
	return 1 if 1 in owned and rng.randf() < 0.3 else 0

func member_force() -> int:
	if perk_kind != 2 or perk_left <= 0: return 1
	return (2 + int(power_levels.get("mask_force", 0))) * (2 if int(power_levels.get("mask_size", 0)) > 0 else 1)

func rescue_from_pit() -> bool:
	if perk_kind != 2 or perk_left <= 0 or revive_charges <= 0 or active_count() > 0 or members.is_empty(): return false
	revive_charges -= 1;hit_grace = 1.5
	for i in range(members.size()):
		var m = members[i];m.falling = false;m.x = slot_x(i);m.y = FLOOR - 160;m.vy = -90;m.glide_left = 1.8;m.jump_delay = -1;m.jump_at = -1;m.coyote = 0
	cached_active = -1
	events.append({"type": "revive", "x": ANCHOR, "y": FLOOR - 75})
	return true

func register_loss() -> void :
	mission_stats.clean_distance=maxi(int(mission_stats.get("clean_distance",0)),int((world_px-last_loss_world)/30))
	last_loss_world=world_px;mission_stats.clean_coin_current=0;mission_stats.clean_tunnel_current=0
	losses += 1;loss_times.append(elapsed)
	while not loss_times.is_empty() and loss_times[0] < elapsed - 4.5: loss_times.pop_front()
	if (loss_times.size() >= 3 or active_count() <= 3) and recovery_left <= 0 and active_count() > 0:
		recovery_left = 3.0 if active_count() >= 24 else 7.0;recovery_speed = maxf(275, speed * 0.93);pressure = maxf(0, pressure - 0.35)
		if developer_kind.is_empty() and not space.active: spawn_civilians(spawn_left() - world_px + 100, 3 if active_count() <= 12 else 1, next_entity_id + 500000)
		events.append({"type": "recovery"})

func remove_member(index: int, cause: String) -> void :
	if index < 0 or index >= members.size(): return
	if bird.prevent_loss(self,members[index],cause): return
	loss_causes[cause] = int(loss_causes.get(cause, 0)) + 1
	var old = members[index]
	var shown = int(old.get("death_kind", old.kind)) if old.falling else (perk_kind if perk_left > 0 else int(old.kind))
	var hit = {"type": "hit", "x": old.x, "y": minf(old.y - 45, FLOOR - 30), "foot_x": member_x(index), "foot_y": float(old.y) - member_depth(index), "kind": shown, "cause": cause}
	if space.active:
		hit.in_space = true;hit.foot_x = old.x;hit.foot_y = old.y;hit.space_height = space.member_height(self);hit.space_wear = cosmetics_for(old,shown).duplicate()
	elif sewer.active:
		hit.in_sewer = true;sewer.casualty(self,old,shown)
	events.append(hit)
	members.remove_at(index);cached_active = -1
	clean_air = false;register_loss()
	if members.is_empty(): finish()

func damage(index: int, cause: String = "impact") -> bool:
	if dead or index < 0 or index >= members.size() or members[index].falling: return false
	if hit_grace > 0 or transform_left > 0 or boost_protected(): return false
	hit_grace = 0.06;clean_air = false
	if blessings.guard(self,Vector2(members[index].x,members[index].y-55)): return true
	if shields > 0:
		if (perk_kind if perk_left > 0 else int(members[index].kind)) == 2:
			members[index].hurt_left = HordeMaskedApprovedSprite.DAMAGE_SECONDS
		shields -= 1;events.append({"type": "guard", "x": members[index].x, "y": members[index].y - 60});return true
	remove_member(index, cause)
	return true

func finish() -> void :
	if dead: return
	dead = true;save_generation_trace();events.append({"type": "finish"})

func update_enemies(dt: float) -> void :
	var pending: Array[Dictionary] = []
	var p = HordeDirector.profile(world_px, active_count(), pressure, recovery_left, tunnel_number())
	for e in entities:
		if e.taken or e.state == "capture": continue
		e.flash = maxf(0, e.flash - dt);e.speech_left = maxf(0, e.speech_left - dt)
		if e.kind in ["civilian", "soldier", "police"] and e.get("speaker", false) and not e.spoke and e.x > ANCHOR + 35 and e.x < ANCHOR + maxf(1000, speed * 3.2) and speech_cooldown <= 0 and speech_left <= 0:
			var phrases = MonsterCatalog.CIVIL_PHRASES if e.kind == "civilian" else (MonsterCatalog.POLICE_PHRASES if e.kind == "police" else MonsterCatalog.ARMY_PHRASES)
			var choices: Array = []
			for phrase in phrases:
				if phrase not in recent_phrases: choices.append(phrase)
			if choices.is_empty(): choices.assign(phrases)
			e.speech = choices[rng.randi_range(0, choices.size() - 1)]
			recent_phrases.append(e.speech)
			while recent_phrases.size() > 3: recent_phrases.pop_front()
			e.spoke = true;e.speech_left = HordeBalance.SPEECH_DURATION;speech_text = e.speech;speech_left = HordeBalance.SPEECH_DURATION
			speech_cooldown = speech_left + rng.randf_range(HordeBalance.SPEECH_GAP.x, HordeBalance.SPEECH_GAP.y)
			speech_npc = 5 if e.kind == "soldier" else (8 if e.kind == "police" else MonsterCatalog.CIVILIANS[e.variant].rig)
			if voice_cooldown <= 0:
				voice_cooldown = 2.2;events.append({"type": "npc_voice", "npc": e.kind, "variant": e.variant})
		if e.get("motion_waiting", false) and world_px >= float(e.motion_start_world):
			e.vx = e.motion_speed;e.motion_waiting = false
		if e.kind == "car" and e.rushing and e.get("rush_waiting", false) and e.x - ANCHOR <= (speed - float(e.rush_speed)) * 2.7 + 180:
			e.vx = e.rush_speed;e.rush_waiting = false;invalidate_coins()
		if e.kind == "car" and e.rushing and not e.warned and e.x > ANCHOR and e.x - ANCHOR < (speed - e.vx) * 2.7 + 180:
			e.warned = true;events.append({"type": "car_warning", "x": e.x, "y": FLOOR - 90})
		if e.kind == "helicopter" and not e.warned and e.x > ANCHOR and e.x - ANCHOR < (speed - e.vx) * 2.7 + 180:
			e.warned = true;events.append({"type": "air_warning", "x": e.x, "y": e.y - 125})
		if e.kind == "soldier": soldier.update(self, e, dt)

func advance(dt: float, jump_held: bool = false) -> void :
	if dead: return
	update_meta_run()
	cached_active = -1
	if not jump_held: release_jump()
	blessings.advance(self,dt)
	elapsed += dt;voice_cooldown = maxf(0, voice_cooldown - dt)
	bird.advance(self,dt)
	speech_left = maxf(0, speech_left - dt);speech_cooldown = maxf(0, speech_cooldown - dt)
	if sewer.active:
		sewer.visual.notice_left = maxf(0,sewer.visual.notice_left-dt)
		sewer.advance(self,dt,jump_held)
		return
	if space.active:
		space.advance(self, dt, jump_held)
		return
	if absf(speed - last_effective_speed) > 2: cruise_speed = speed / maxf(0.2, time_scale)
	if transform_left > 0:
		transform_left = maxf(0, transform_left - dt)
		time_scale = move_toward(time_scale, 0.22, dt * 2.2)
		speed = cruise_speed * time_scale;last_effective_speed = speed
		world_px += speed * dt;update_tunnels()
		for e in entities:
			if e.kind == "bullet": e.previous_x = e.x;e.previous_y = e.y
			e.x += ( - speed + float(e.vx) * time_scale) * dt
			if e.kind == "bullet": e.y += float(e.vy) * dt * time_scale
		update_civilians(dt * time_scale);update_enemies(dt * time_scale)
		while next_segment < 99999 and next_pattern_world - world_px < generation_horizon(): spawn_next_pattern()
		for member in members: member.run_phase += dt * 0.75
		if transform_left <= 0:
			activate_perk(transform_kind);transform_kind = -1
			for member in members: member.glide_left = maxf(member.glide_left, 1.1)
		return
	boost_left = maxf(0, boost_left - dt);recovery_left = maxf(0, recovery_left - dt)
	var p = HordeDirector.profile(world_px, active_count(), pressure, recovery_left, tunnel_number())
	pressure = move_toward(pressure, float(p.pressure_target), dt * 0.17)
	var target_speed = float(p.speed)
	surge_left = maxf(0, surge_left - dt);surge_warning_left = maxf(0, surge_warning_left - dt)
	if developer_kind.is_empty() and active_count() >= 36 and recovery_left <= 0 and boost_left <= 0 and not inside_tunnel() and elapsed >= next_surge_at:
		var clear = true
		for threat in entities:
			if not threat.taken and threat.kind not in ["coin", "civilian"] and threat.x > ANCHOR - 80 and threat.x < ANCHOR + speed * 1.4: clear = false;break
		if clear:
			surge_left = 7.0;surge_warning_left = 1.0;next_surge_at = elapsed + rng.randf_range(24, 36)
			events.append({"type": "surge_warning"})
	if surge_left > 0 and surge_warning_left <= 0: target_speed *= 1.06
	if recovery_left > 0: target_speed = minf(target_speed, recovery_speed)
	target_speed *= 1.18 if boost_left > 0 else 1.0
	cruise_speed = move_toward(cruise_speed, target_speed, dt * 58)
	time_scale = move_toward(time_scale, 0.86 if perk_kind == 3 and perk_left > 0 else 1.0, dt * 0.72)
	speed = cruise_speed * time_scale;last_effective_speed = speed
	var step = speed * dt;world_px += step
	update_tunnels()
	if boost_left > 0: boost_px += step
	hit_grace = maxf(0, hit_grace - dt)
	if tunnel_number() != last_tunnel:
		last_tunnel = tunnel_number()
		events.append({"type": "tunnel", "area": area(), "number": last_tunnel})
	if area() != last_area:
		last_area = area();events.append({"type": "area", "area": last_area})
	if perk_left > 0:
		perk_left = maxf(0, perk_left - dt)
		if perk_left <= 0:
			if perk_kind == 3:
				for m in members:
					if not m.falling: m.glide_left = 0.3
			perk_kind = -1;events.append({"type": "perk_end"})
	for entity in entities:
		if entity.kind == "bullet":
			entity.previous_x = entity.x;entity.previous_y = entity.y

		entity.x += ( - speed + float(entity.vx)) * dt
		if entity.kind == "bullet": entity.y += float(entity.vy) * dt
	update_projectile_impacts()
	update_civilians(dt)
	update_enemies(dt)
	update_collapses(dt)
	rebuild_surfaces()
	while next_segment < 99999 and next_pattern_world - world_px < generation_horizon():
		spawn_next_pattern()
	if developer_kind.is_empty():
		sewer.encounter.tick(self)
		if sewer.active: return
		space.offer_test_pickup(self)
		bonus_director.tick(self)
	refresh_formation()
	for i in range(members.size() - 1, -1, -1):
		var m = members[i]
		if m.falling:
			m.x -= step
		else: m.x = reform_x(m, slot_x(i), dt)
		var half_width = 43.0 * (1.4 if perk_kind == 2 and perk_left > 0 and int(power_levels.get("mask_size", 0)) > 0 else 1.0)
		if not m.falling and float(m.x) + half_width < view_left - 7.0:
			remove_member(i, "camera");continue
		var cadence = HordeZombieStride.cycle_rate(speed) if int(m.kind) == 0 and perk_left <= 0 else clampf(speed / 240.0, 1.15, 2.65)
		m.run_phase += dt * cadence
		m.hurt_left = maxf(0, float(m.get("hurt_left", 0)) - dt)
		m.mask_flip_left = maxf(0, float(m.get("mask_flip_left", 0)) - dt)
		m.attack_left = maxf(0, m.attack_left - dt);m.push_left = maxf(0, m.push_left - dt)
		m.land_left = maxf(0, m.land_left - dt);m.arrival = maxf(0, m.arrival - dt);m.glide_left = maxf(0, m.glide_left - dt)

		if not m.falling:
			for j in range(1, terrain.segments.size()):
				var segment = terrain.segments[j]
				if float(segment.height) <= float(terrain.segments[j - 1].height): continue
				var edge = float(segment.start) - world_px
				if m.x + 18 >= edge and m.x + 18 - step - dt * HordeTuning.REFORM_WALK_SPEED <= edge + 1.0 and m.y > FLOOR - float(segment.height) + 1:
					if boost_protected(): m.y = FLOOR - float(segment.height);m.vy = 0.0
					else: m.x = edge - 18
		var support = member_floor(m)
		var floor_here = bool(support.solid)
		var floor_y = float(support.y)
		if int(support.roof) >= 0 and int(m.roof_id) == int(support.roof) and float(m.vy) == 0 and absf(float(m.y) - floor_y) < 6: m.y = floor_y
		m.roof_id = int(support.roof);m.surface_y = floor_y
		m.air_pose = move_toward(float(m.air_pose), 1.0 if m.y < floor_y - 4 else 0.0, dt * 7)
		var previous_y = float(m.y)
		var was_grounded = not m.falling and m.y >= floor_y - 0.1 and m.y <= floor_y + 2 and m.vy >= 0 and floor_here
		if was_grounded: m.coyote = 0.1;m.air_jumps = 0
		else: m.coyote = maxf(0, m.coyote - dt)
		HordeJump.step(self, m, was_grounded)

		var flying = not m.falling and perk_kind == 3 and perk_left > 0
		if flying:




			var flight_ground: float = ground_y(float(m.x))
			var target_y: float = floor_y if jump_held else minf(flight_ground, floor_y) - 175.0
			var target_vy: float = clampf((target_y - float(m.y)) * 4.0, -220.0, 260.0)
			m.vy = move_toward(float(m.vy), target_vy, dt * 1250.0)
			m.y += float(m.vy) * dt
			m.y = clampf(float(m.y), flight_ground - 235.0, flight_ground + 2.0)
			if jump_held and floor_here and previous_y <= floor_y + 2.0 and float(m.y) >= floor_y and float(m.vy) >= 0.0:
				m.y = floor_y;m.vy = 0.0
			if m.y == floor_y and previous_y < floor_y - 2:
				m.reform_hold_until = elapsed + HordeTuning.LANDING_RECOVERY_SECONDS
				m.land_left = HordeMaskedApprovedSprite.LANDING_SECONDS if (perk_kind if perk_left > 0 else int(m.kind)) == 2 else 0.2;events.append({"type": "land", "x": m.x, "y": floor_y, "leader": i == 0})
		else:


			var wave = int(m.wave_id)
			var recorded = float(wave_durations.get(wave, HordeBalance.MAX_HOLD if bool(wave_holds.get(wave, false)) else HordeTuning.MIN_TAP_HOLD))
			var hold_for = maxf(HordeTuning.MIN_TAP_HOLD, recorded)
			var held = not m.falling and bool(m.get("hold_open", false)) and float(m.air_time) < hold_for
			var hold_step = minf(dt, maxf(0, hold_for - float(m.air_time))) if held else 0.0
			if hold_step > 0: HordeBalance.integrate(m, hold_step, true)
			if dt - hold_step > 1e-06: HordeBalance.integrate(m, dt - hold_step, false)
			if not m.falling and m.glide_left > 0 and not floor_here and m.y > FLOOR - 60:
				m.y = FLOOR - 60;m.vy = 0.0

			elif not m.falling and floor_here and previous_y <= floor_y + (12.0 if int(support.roof) >= 0 else 0.01) and m.y >= floor_y and m.vy >= 0:
				if not was_grounded:
					m.reform_hold_until = elapsed + HordeTuning.LANDING_RECOVERY_SECONDS
				if m.vy > 250:
					m.land_left = HordeMaskedApprovedSprite.LANDING_SECONDS if (perk_kind if perk_left > 0 else int(m.kind)) == 2 else 0.2;events.append({"type": "land", "x": m.x, "y": floor_y, "leader": i == leader_index()})
					if i == leader_index() and clean_air: clean_jumps += 1;clean_air = false
				m.landed_at = elapsed - dt + dt * clampf((floor_y - previous_y) / maxf(1e-05, float(m.y) - previous_y), 0, 1) if not was_grounded else float(m.get("landed_at", -1))
				m.y = floor_y;m.vy = 0;m.air_jumps = 0
			if boost_protected() and not m.falling and m.y > floor_y: m.y = floor_y;m.vy = 0.0
			if m.y > FLOOR + 12:
				if not m.falling: m.death_kind = perk_kind if perk_left > 0 else int(m.kind)
				cached_active = -1
				m.falling = true;m.jump_queue.clear();m.jump_delay = -1.0;m.jump_at = -1.0;m.coyote = 0.0;m.glide_left = 0.0
		if not m.falling: HordeBalance.resolve_ceiling(m, previous_y, physics_surfaces)
		if m.y > FLOOR + 145 and active_count() == 0: rescue_from_pit()
		if m.y > FLOOR + 170:
			remove_member(i, "fall")
		elif int(m.formation_rank) < 3 and not m.falling and m.y >= floor_y - 0.1 and m.y <= floor_y + 0.1 and floor_here and m.jump_delay < 0:
			var phase = int(float(m.run_phase) * 2)
			if phase != m.step_phase:
				m.step_phase = phase;events.append({"type": "step", "x": m.x - 6, "y": floor_y - member_depth(i)})
	separate_members(dt)
	if jump_buffer_until >= 0: HordeJump.resolve_buffer(self)
	if members.is_empty(): finish();return
	var lead = leader_index()
	if lead < 0: return
	for e in entities:
		if e.taken: continue
		if dead or members.is_empty(): break
		lead = leader_index()
		if lead < 0: break
		var body = members[lead]
		var centre = Vector2(body.x, body.y - 48)
		if e.kind == "eye":
			if centre.distance_to(Vector2(e.x, e.y)) < 54:
				e.taken = true;eyes_collected += 1;events.append({"type": "eye", "x": e.x, "y": e.y})
			continue
		if e.kind == "coin":
			var radius = 175.0 if run_items.has("coin_magnet") else 54.0 + (30 if boost_left > 0 else 0)
			if coin_in_reach(Vector2(e.x,e.y),radius):
				var amount = 2 if boost_left > 0 else 1
				e.taken = true;coins += amount;collect_coin_row(e)
				mission_stats.clean_coin_current=int(mission_stats.get("clean_coin_current",0))+amount
				mission_stats.clean_coins=maxi(int(mission_stats.get("clean_coins",0)),int(mission_stats.clean_coin_current))
				if boost_left>0: mission_stats.frenzy_coins=int(mission_stats.get("frenzy_coins",0))+amount
				events.append({"type":"coin","amount":amount,"x":e.x,"y":e.y,"physical_pickup":true,"frenzy_pickup":boost_left>0})
			continue
		if e.kind in ["civilian", "soldier", "police"]:
			if e.state == "normal":
				for i in range(members.size()):
					var m = members[i]
					if m.falling or m.attack_left > 0: continue
					if Vector2(m.x, m.y - 52).distance_to(Vector2(e.x, e.y - 50)) < 62:
						begin_capture(e, m);break
			continue
		if e.kind=="sewer_key": e.taken = true;continue
		if e.kind in ["crystal", "mask", "shield", "boost", "space_brain", "harvester", "spectral"]:
			if e.kind == "mask" and 2 not in power_owned: continue
			if not power_eligible(): e.taken = true;continue
			if centre.distance_to(Vector2(e.x, e.y)) < 72:
				e.taken = true
				match e.kind:
					"harvester": grant_perk(5)
					"spectral": grant_perk(6)
					"space_brain":
						if space.begin(self): return
					"crystal": grant_perk(3)
					"mask": grant_perk(2)
					"shield": mark_power_collected();shields = 1;bonuses += 1;events.append({"type": "guard", "x": e.x, "y": e.y})
					"boost": mark_power_collected();boost_left = HordeTuning.BOOST_SECONDS;boost_warning_tick = 4;bonuses += 1;events.append({"type": "boost", "x": e.x, "y": e.y})
			continue
		if MonsterCatalog.VEHICLES.has(e.kind):
			update_vehicle(e, dt);continue
		if e.kind not in ["crate", "spikes", "hump", "bomb", "bullet", "helicopter", "air_bomb"]: continue
		if e.x > ANCHOR + 200 or e.x < -150: continue
		for i in range(members.size()):
			var m = members[i]
			if m.falling: continue
			var overlapping = HordeBalance.projectile_swept_hit(e, m) if e.kind == "bullet" else HordeBalance.hazard_hits(e, m)
			if not overlapping: continue
			if e.kind == "bomb" and run_items.has("coin_bombs"):
				if not e.has("gold_roll"): e.gold_roll = reward_rng.randf() < 0.25
				if e.gold_roll:
					e.taken = true;coins += 12;events.append({"type": "coin", "amount": 12, "x": e.x, "y": e.y - 40});break
			if e.kind == "bullet" and str(e.get("shot_mode", "")) == "rocket":
				soldier.explode(self, e);break
			if ((perk_kind == 2 and perk_left > 0) or boost_protected()) and e.kind in ["crate", "spikes", "bomb", "air_bomb", "bullet"]:
				e.taken = true
				if e.kind in ["bomb","air_bomb"]: mission_stats.bombs_broken=int(mission_stats.get("bombs_broken",0))+1
				events.append({"type": "smash", "object": e.kind, "x": e.x, "y": e.y - 35 if e.y == FLOOR else e.y})
			else:
				var applied = damage(i, e.kind)
				if e.kind in ["bomb", "bullet", "helicopter", "air_bomb"] and applied:
					e.taken = true
					if e.kind != "bullet": events.append({"type": "explosion", "x": e.x, "y": e.y - 35 if e.y == FLOOR else e.y})
			break
	update_power_warnings()
	for i in range(entities.size() - 1, -1, -1):
		if entities[i].x < -850 and entities[i].state != "capture":
			miss_coin_row(entities[i]);entities.remove_at(i)

func new_coin_row(count: int) -> int:
	var id = next_coin_row;next_coin_row += 1
	coin_rows[id] = {"total":count,"collected":0,"missed":false}
	return id

func coin_in_reach(point: Vector2, radius: float) -> bool:
	for m in members:
		if not m.falling and Vector2(m.x,m.y-48).distance_to(point)<radius: return true
	return false

func collect_coin_row(e: Dictionary) -> void:
	var id = int(e.get("coin_row",-1))
	if not coin_rows.has(id): return
	var row: Dictionary = coin_rows[id]
	row.collected += 1
	if row.collected == row.total:
		if not row.missed and int(row.total)>=3:
			mission_stats.perfects = int(mission_stats.get("perfects",0))+1
			bird.on_perfect(self)
			events.append({"type":"perfect","x":e.x,"y":e.y,"count":row.total})
		coin_rows.erase(id)

func miss_coin_row(e: Dictionary) -> void:
	var id = int(e.get("coin_row",-1))
	if coin_rows.has(id): coin_rows.erase(id)

func distance() -> int:
	return int(world_px / 30.0)

func stats() -> Dictionary:
	var result = {"distance": distance(), "coins": coins, "recruits": recruits, "souls": souls, "soldiers": soldiers, "rescues": rescues, "groups": groups, "cars": cars,
		"jumps": clean_jumps, "bonuses": bonuses, "horde": max_horde, "flights": flights, "boost": int(boost_px / 30), "tunnels": completed_tunnels, "losses": losses}
	for key in ["civilians","civil_groups","army","fly_captures","mask_captures","skeleton_captures","vehicle_car","vehicle_moto","vehicle_bus","vehicle_truck","vehicle_tank","vehicle_plane","mask_vehicles","bombs_broken","frenzy_coins","clean_tunnel_streak","clean_coins"]: result[key]=int(mission_stats.get(key,0))
	result.seconds=floori(elapsed);result.clean_distance=maxi(int(mission_stats.get("clean_distance",0)),int((world_px-last_loss_world)/30))
	return result

func drain_events() -> Array[Dictionary]:
	var result = events.duplicate();events.clear();return result

func schedule_tunnel(number: int, entry: float) -> void :
	var predicted = HordeDirector.stage_speed(maxi(0, number - 1))
	tunnels.append({"number": number, "entry": entry, "length": clampf(predicted * 5.5, 2100, 4200), "from": route[(number - 1) % route.size()], "to": route[number % route.size()], "entered": false, "completed": false})

func current_tunnel() -> Dictionary:
	for t in tunnels:
		if world_px < float(t.entry) + float(t.length): return t
	return {}

func ensure_tunnels(through: float) -> void :
	if not developer_kind.is_empty(): return
	if tunnels.is_empty(): schedule_tunnel(1, HordeTuning.TUNNEL_DISTANCE)
	while float(tunnels[-1].entry) + float(tunnels[-1].length) < through:
		var previous = tunnels[-1]
		var number = int(previous.number) + 1
		var interval = HordeTuning.tunnel_interval(HordeDirector.stage_speed(number - 1))
		schedule_tunnel(number, float(previous.entry) + float(previous.length) + interval)

func update_tunnels() -> void :
	if not developer_kind.is_empty(): return
	ensure_tunnels(world_px + 45000)
	for t in tunnels:

		if not bool(t.get("rewards_spawned", false)) and world_px >= float(t.entry) - 1800.0:
			t.rewards_spawned = true
			spawn_tunnel_rewards(t)
		if not t.entered and world_px >= float(t.entry):
			t.entered = true;entered_tunnels = int(t.number);t.mission_entry_losses=losses
			events.append({"type": "tunnel_enter", "number": entered_tunnels})
		if not t.completed and world_px >= float(t.entry) + float(t.length):
			t.completed = true;completed_tunnels = int(t.number)
			if losses==int(t.get("mission_entry_losses",losses)):
				mission_stats.clean_tunnel_current=int(mission_stats.get("clean_tunnel_current",0))+1
				mission_stats.clean_tunnel_streak=maxi(int(mission_stats.get("clean_tunnel_streak",0)),int(mission_stats.clean_tunnel_current))
			else: mission_stats.clean_tunnel_current=0
			save_generation_trace()
			events.append({"type": "tunnel_exit", "number": completed_tunnels, "area": area()})
			break

func spawn_tunnel_rewards(t: Dictionary) -> void :
	if not developer_kind.is_empty(): return
	var length: float = float(t.length)
	var start: float = ANCHOR + float(t.entry) - world_px
	var floor_y: float = ground_y(start + 320.0)


	for lane in range(3):
		var x_base: float = start + length * (0.18 + float(lane) * 0.24)
		for i in range(4):
			var cx: float = x_base + float(i) * 52.0
			add_entity("coin", cx, floor_y - 60.0 - (15.0 if i in [1, 2] else 0.0))

	var recruits: int = mini(6, 2 + int(active_count() / 12))
	var allowed: int = mini(recruits, remaining_soul_slots())
	var group: int = 3000000 + int(t.number) * 100
	var civil_x: float = start + length * 0.43
	for i in range(allowed):
		var at: float = civil_x + float(i) * 80.0
		var person: Dictionary = add_entity("civilian", at, ground_y(at), reward_rng.randi_range(0, 2))
		person.group = group


	if active_count() >= 8 and remaining_soul_slots() >= 2 and reward_rng.randf() < 0.2:
		var car_x: float = start + length * 0.77
		add_entity("car", car_x, ground_y(car_x))

func spawn_civilians(x: float, count: int, group_id: int) -> void :
	if souls >= early_soul_limit(): return
	if generation_started: x = maxf(x, spawn_left() - world_px + 60)
	count = clampi(count, 1, 6)
	if count >= 3 and world_px + x - last_three_world < 1800: count = 2

	var clear = false
	for attempt in range(24):
		clear = true
		for i in range(count):
			if not civilian_floor_safe(x + i * 92, 85) or not safe_world_position(world_px + x + i * 92): clear = false;break
		if clear: break
		x += 160
	if not clear: return
	var added = 0
	for i in range(count):
		var at = x + i * 92
		var e = add_entity("civilian", at, ground_y(at), posmod(group_id + i, 3));e.group = group_id;added += 1
	if added >= 3: last_three_world = world_px + x

func member_by_id(id: int) -> Dictionary:
	for m in members:
		if int(m.id) == id and not m.falling: return m
	return {}

func begin_capture(entity: Dictionary, member: Dictionary) -> void :
	if dead or member.falling or entity.state != "normal": return
	var capture_kind: int = perk_kind if perk_left > 0 else int(member.kind)
	var duration: float = HordeFlyApprovedSprite.CAPTURE_SECONDS if capture_kind == 3 else 0.62
	if entity.kind == "soldier" and capture_kind != 3: duration = 0.82
	entity.state = "capture";entity.capture_left = duration;entity.capture_duration = duration;entity.capturer = member.id
	if entity.kind == "soldier": entity.vx = 0.0;entity.weapon_t = 0.0;entity.flash = 0.0
	if entity.has("woman_clip"):
		entity.woman_clip = "capture";entity.woman_time = 0.0
	if entity.get("civil_key", "") == "civil_casaco_azul_nerd":
		entity.civil_capture_transition = entity.civil_clip == "corrida" and HordeCivilSprite.sample("corrida", entity.civil_time) <= 2
		civil_turn(entity, true)
	entity.capture_kind = capture_kind
	entity.capture_offset = Vector2(32 + int(entity.id) % 3 * 9, -6)
	member.attack_left = duration
	member.attack_duration = duration
	member.attack_kind = capture_kind
	events.append({"type": "capture", "kind": entity.capture_kind, "x": entity.x, "y": entity.y - 50})

func update_civilians(dt: float) -> void :
	for e in entities:
		if e.taken: continue
		e.age += dt
		if e.kind in ["helicopter", "air_bomb"]:
			e.y = e.base_y + sin(elapsed * 3 + e.bob) * 6
		if e.kind not in ["civilian", "soldier", "police"]: continue
		if e.state == "capture":
			var m = member_by_id(int(e.capturer))
			if m.is_empty():
				e.state = "normal";e.pose = "panic";e.vy = -120
				if e.has("woman_clip"):
					e.woman_clip = "run";e.woman_time = 0.0;e.vx = float(e.flee_speed)
				if e.has("civil_key"): e.civil_clip = "corrida";e.civil_time = 0.0;civil_turn(e, false)
				continue
			e.x = m.x + e.capture_offset.x;e.y = m.y + e.capture_offset.y
			if e.has("worker_time"): e.worker_time += dt
			if e.has("civil_key"): e.civil_turn_left = maxf(0, float(e.civil_turn_left) - dt)
			e.capture_left -= dt
			if e.capture_left <= 0 and active_count() > 0 and not dead: complete_capture(e)
		elif e.kind in ["civilian", "police"]:
			if e.has("worker_clip"):
				update_worker_civil(e, dt)
				e.y = ground_y(e.x)
				continue
			if e.get("airdrop",false):
				e.drop_vy = float(e.drop_vy)+1100*dt;e.y += float(e.drop_vy)*dt
				if float(e.y)>=ground_y(e.x) and has_floor(e.x):
					e.y = ground_y(e.x);e.airdrop = false;e.vy = 0.0
				continue
			if e.has("civil_key"):
				update_blue_civil(e, dt)
				e.y = ground_y(e.x)
				continue
			if e.kind == "civilian" and e.has("woman_clip"):
				update_woman_civil(e, dt)
				e.y = ground_y(e.x)
				continue
			protect_civilian_path(e)
			if e.vy != 0:
				e.vy += GRAVITY * dt;e.y += e.vy * dt
				if e.y >= ground_y(e.x) and e.vy > 0: e.y = ground_y(e.x);e.vy = 0
			else:
				e.y = ground_y(e.x) - absf(sin(e.age * (3.0 if e.pose == "hop" else 4.5) + e.bob)) * (42 if e.pose == "hop" else (9 if e.pose == "panic" else 0))

func complete_capture(entity: Dictionary) -> void :
	if entity.taken or dead or active_count() == 0: return
	entity.taken = true;entity.state = "converted"
	souls += 1;recruits += 1
	if entity.kind=="soldier": mission_stats.army=int(mission_stats.get("army",0))+1
	if entity.kind=="civilian" and not bool(entity.get("from_vehicle",false)):
		mission_stats.civilians=int(mission_stats.get("civilians",0))+1
		var counter = str({1:"skeleton_captures",2:"mask_captures",3:"fly_captures"}.get(int(entity.get("capture_kind",0)),""))
		if not counter.is_empty(): mission_stats[counter]=int(mission_stats.get(counter,0))+1
	if entity.kind in ["soldier", "police"]: soldiers += 1
	if entity.rescued: rescues += 1
	if int(entity.group) >= 0:
		var count = int(group_captures.get(entity.group, 0)) + 1;group_captures[entity.group] = count
		if count == 3:
			groups += 1
			if entity.kind=="civilian" and not bool(entity.get("from_vehicle",false)): mission_stats.civil_groups=int(mission_stats.get("civil_groups",0))+1
	var kind = recruit_kind()


	var join_x: = slot_x(members.size())


	add_member(kind, false, Vector2(join_x, ground_y(join_x)))
	if not members.is_empty():
		members[-1].arrival = 0.0
		members[-1].reform_hold_until = elapsed
	events.append({"type": "soul", "kind": kind, "x": entity.x, "y": entity.y - 58, "soldier": entity.kind in ["soldier", "police"], "from_vehicle": entity.get("from_vehicle", false)})

func update_vehicle(entity: Dictionary, dt: float) -> void :
	if entity.x - entity.width * 0.5 > ANCHOR + 80 or entity.x + entity.width * 0.5 < -150: return
	if entity.rushing: update_rushing_car(entity);return
	if boost_protected():
		for member in members:
			if not member.falling and HordeBalance.hazard_hits(entity, member): flip_vehicle(entity);return
	var spec = MonsterCatalog.VEHICLES[entity.kind]
	var need = int(entity.get("required_count", spec.need))

	var alive = {}
	for m in members:
		if not m.falling: alive[m.id] = true
	for id in entity.contacts.keys():
		var member = member_by_id(int(id))
		if not alive.has(id) or member.is_empty():
			entity.contacts.erase(id);continue
		var member_kind: int = perk_kind if perk_left > 0 else int(member.kind)
		var reach: float = HordeFlyApprovedSprite.push_reach() if member_kind == 3 else (HordeMaskedApprovedSprite.push_reach(112.0 * (1.4 if perk_kind == 2 and perk_left > 0 and int(power_levels.get("mask_size", 0)) > 0 else 1.0)) if member_kind == 2 else 18.0)
		if member.y < entity.y - 12 or absf(float(member.x) - (float(entity.x) - float(entity.width) * 0.5 - reach)) > 70: entity.contacts.erase(id)
	var edge = float(entity.x) - float(entity.width) * 0.5
	var right_edge = float(entity.x) + float(entity.width) * 0.5



	var bumper_reach = 18.0 + maxf(8.0, speed * dt)
	var trapped_ids: Array[int] = []
	for m in members:
		if m.falling or m.y <= entity.y - float(entity.roof) + 12 or m.y > entity.y + 2 or not has_floor(m.x): continue
		var member_kind: int = perk_kind if perk_left > 0 else int(m.kind)
		var reach: float = HordeFlyApprovedSprite.push_reach() if member_kind == 3 else (HordeMaskedApprovedSprite.push_reach(112.0 * (1.4 if perk_kind == 2 and perk_left > 0 and int(power_levels.get("mask_size", 0)) > 0 else 1.0)) if member_kind == 2 else 18.0)
		if m.x < edge - (reach - 2.0) or m.x > right_edge - 4: continue
		if m.x > edge + bumper_reach:

			if m.x >= right_edge - maxf(18.0, speed * dt * 2.0): continue
			if m.y > entity.y - float(entity.roof) + 16: trapped_ids.append(int(m.id))
			continue
		if not entity.contacts.has(m.id):
			if m.y >= entity.y - 12:
				entity.contacts[m.id] = member_force();entity.state = "pushing"
				m.mask_push_at = elapsed
			events.append({"type": "contact", "x": edge, "y": entity.y - 30, "count": entity.contacts.size(), "need": need})
		m.push_left = 0.42 if perk_kind == 3 and perk_left > 0 else 0.15
		m.x = minf(m.x, edge - reach)


	for id in trapped_ids:
		for i in range(members.size()):
			if int(members[i].id) == id:
				damage(i, "vehicle")
				break
	# Grounded neighbours transmit their push through the queue. They do not
	# need to occupy the same bumper position to contribute their strength.
	var queue: Array = members.filter(func(m): return not m.falling and float(m.y) >= float(entity.y) - 12 and float(m.y) <= float(entity.y) + 2 and absf(float(m.vy)) < 1 and has_floor(float(m.x)) and float(m.x) <= edge + 2)
	queue.sort_custom(func(a, b): return float(a.x) > float(b.x))
	var connected = {}
	var previous_x = INF
	for m in queue:
		var touching = entity.contacts.has(m.id) or (not connected.is_empty() and previous_x - float(m.x) <= 46.0)
		if not touching: continue
		connected[m.id] = member_force();previous_x = float(m.x)
		if not entity.contacts.has(m.id): m.mask_push_at = elapsed
		m.push_left = 0.15
	entity.contacts = connected
	var count = entity.contacts.size()
	var effort = 0
	for value in entity.contacts.values(): effort += int(value)
	var damage_stage = mini(2, int(float(effort) / float(need) * 3))
	if damage_stage > int(entity.damage_stage):
		entity.damage_stage = damage_stage;events.append({"type": "glass", "x": entity.x, "y": entity.y - float(entity.height) * 0.7})
	entity.tilt = move_toward(entity.tilt, minf(0.62, float(effort) / float(need) * 0.72), dt * 2.5)
	if entity.state == "pushing":
		entity.push_age += dt
		if effort >= need:
			flip_vehicle(entity)
		elif entity.push_age > 1.35 and not entity.get("weak_warned", false):
			entity.weak_warned = true
			events.append({"type": "weak_vehicle", "x": entity.x, "y": entity.y - 120, "count": count, "need": need})

func flip_vehicle(entity: Dictionary) -> void :
	if entity.taken: return
	var flip_delay = 0.0
	for id in entity.contacts:
		var member: Dictionary = member_by_id(int(id))
		if not member.is_empty() and (perk_kind if perk_left > 0 else int(member.kind)) == 2:
			var preparation = minf(0.34, maxf(0.0, elapsed - float(member.get("mask_push_at", elapsed))))
			member.mask_flip_left = HordeMaskedApprovedSprite.FLIP_SECONDS - preparation
			flip_delay = maxf(flip_delay, maxf(0.0, 0.2 - preparation))
		if not member.is_empty() and (perk_kind == 3 and perk_left > 0 or int(member.kind) == 3): member.push_left = 0.0
	var spec = MonsterCatalog.VEHICLES[entity.kind]
	entity.taken = true;entity.roof_hold_until = elapsed + 0.9;cars += 1
	var counter="vehicle_"+str(entity.kind);mission_stats[counter]=int(mission_stats.get(counter,0))+1
	if perk_kind==2 and perk_left>0: mission_stats.mask_vehicles=int(mission_stats.get("mask_vehicles",0))+1
	if run_items.has("coin_cars") and reward_rng.randf() < 0.25:
		coins += 25;events.append({"type": "coin", "amount": 25, "x": entity.x, "y": entity.y - 100})
	coins += int(spec.reward)
	var presentation = {"type": "smash", "object": entity.kind, "x": entity.x, "y": entity.y - float(entity.height) * 0.5, "tilt": entity.tilt, "flip_delay": flip_delay, "width": entity.width, "height": entity.height, "floor_y": entity.y, "rescued_count": entity.passengers.size(), "passenger_variants": entity.passengers.duplicate(), "join_ids": []}
	events.append(presentation)
	events.append({"type": "coin", "amount": spec.reward, "x": entity.x, "y": entity.y - 120})
	for i in range(entity.passengers.size()):


		var human = {"taken": false, "state": "normal", "kind": "civilian", "rescued": true, 
			"x": entity.x - float(entity.width) * 0.25 + i * 22, "y": entity.y - 20, 
			"group": entity.id + 2000000, "from_vehicle": true}
		var old_count = members.size()
		complete_capture(human)
		presentation.join_ids.append(int(members[-1].id) if members.size() > old_count else -1)

func helicopter_front_hit(entity: Dictionary, member: Dictionary) -> bool:
	return HordeBalance.hazard_hits(entity, member)

func civilian_floor_safe(x: float, margin: float = 34) -> bool:
	for e in entities:
		if e.kind in ["gap", "collapse"] and x > e.x - margin and x < e.x + e.width + margin: return false
	if terrain.near_edge(world_px + x, minf(margin, 130)): return false
	return true

func protect_civilian_path(e: Dictionary) -> void :
	for gap in entities:
		if gap.kind not in ["gap", "collapse"]: continue
		var left = float(gap.x) - 38
		var right = float(gap.x) + float(gap.width) + 38
		if e.x > left and e.x < right:
			if e.x < (left + right) * 0.5: e.x = left;e.vx = - maxf(45, absf(e.vx))
			else: e.x = right;e.vx = maxf(45, absf(e.vx))
		elif e.x <= left and e.vx > 0 and e.x + e.vx * 0.5 > left: e.vx = - maxf(45, e.vx);e.pose = "panic"
		elif e.x >= right and e.vx < 0 and e.x + e.vx * 0.5 < right: e.vx = maxf(45, - e.vx);e.pose = "panic"

func power_eligible() -> bool:

	return not space.active and not sewer.active and not sewer.encounter.pending and not blessings.active() and transform_left <= 0 and perk_left <= 0 and boost_left <= 0

func mark_power_collected() -> void :
	bonus_director.collected(self)
	for entity in entities:
		if entity.kind in ["crystal", "mask", "shield", "boost", "space_brain","harvester","spectral","sewer_key"]: entity.taken = true

func try_spawn_power(x: float) -> bool:
	var before = bonus_director.last_opportunity
	bonus_director.tick(self)
	return bonus_director.last_opportunity > before

func spawn_rushing_car(x: float, group_id: int, deferred: bool = false) -> Dictionary:
	var car = add_entity("car", x, ground_y(x), -89);car.rushing = true;car.vx = - clampf(cruise_speed * 0.58, 165, 340)
	car.rush_speed = car.vx;car.rush_waiting = false
	car.passengers.clear();car.group = group_id
	next_rush_world = maxf(next_rush_world, world_px + x + maxf(6000, speed * 15))
	invalidate_coins()
	return car

func update_rushing_car(car: Dictionary) -> void :
	if car.taken: return
	for i in range(members.size()):
		var m = members[i]
		if m.falling or m.y <= car.y - float(car.roof) + 3 or m.y > car.y + 4: continue

		if absf(m.x - (float(car.x) - float(car.width) * 0.5)) > 30: continue

		car.taken = true
		damage(i, "rushing_car")
		events.append({"type": "rush_crash", "x": car.x, "y": car.y - float(car.height) * 0.5, "object": "car", "width": car.width, "height": car.height, "floor_y": car.y})
		return

func early_soul_limit() -> int:

	if not developer_kind.is_empty(): return 999999
	var stage = tunnel_number()
	return [18, 29, 43, 57, 67, 76][stage] if stage <= 5 else 76 + (stage - 5) * 12

func remaining_soul_slots() -> int:
	var pending = 0
	for entity in entities:
		if entity.taken: continue
		if entity.kind in ["civilian", "soldier", "police"]: pending += 1
		elif MonsterCatalog.VEHICLES.has(entity.kind): pending += entity.passengers.size()
	return maxi(0, early_soul_limit() - souls - pending)

func follower_delay(rank: int) -> float:
	# Travel to the leader's launch point is handled by the jump command.
	# Additional reaction delay starts in crowds of roughly 16-20 members.
	var n = maxi(0,rank-15)
	return minf(.55,n*jump_delay_step*2.2+maxi(0,n-13)*jump_delay_step*.35)

func boost_protected() -> bool:
	return boost_left > 0 and int(levels.get("frenzy", 0)) > 0

func rebuild_surfaces() -> void :
	physics_surfaces.clear()
	physics_gaps.clear()
	for e in entities:
		if not e.taken and e.kind in ["gap", "collapse"] and float(e.x) <= ANCHOR + 120 and float(e.x) + float(e.width) >= -150: physics_gaps.append(e)
		if not (MonsterCatalog.VEHICLES.has(e.kind) or e.kind == "helicopter"): continue
		if e.taken and elapsed > float(e.get("roof_hold_until", -1.0)): continue
		var body = HordeBalance.surface(e)
		if body.end.x >= -150 and body.position.x <= ANCHOR + 90: physics_surfaces.append(e)

func update_power_warnings() -> void :
	var seconds = ceili(perk_left)
	if seconds > 0 and seconds <= 3 and seconds < power_warning_tick:
		power_warning_tick = seconds;events.append({"type": "power_warning"})
	seconds = ceili(boost_left)
	if seconds > 0 and seconds <= 3 and seconds < boost_warning_tick:
		boost_warning_tick = seconds;events.append({"type": "power_warning"})

static func civil_turn(e: Dictionary, flipped: bool) -> void :
	if bool(e.get("civil_flip", true)) == flipped: return
	e.civil_previous_flip = e.get("civil_flip", true);e.civil_flip = flipped;e.civil_turn_left = 0.09

func update_worker_civil(e: Dictionary, dt: float) -> void :
	e.worker_time = float(e.worker_time) + dt
	e.vx = 0.0;e.vy = 0.0
	var clip = str(e.worker_clip)
	if clip == "recover" and float(e.worker_time) >= HordeWorkerSprite.RECOVER_SECONDS:
		e.worker_clip = "defesa";e.worker_time = 0.0
	elif clip == "desastrado":
		var lead = leader_index()
		if lead >= 0 and float(e.x) - float(members[lead].x) < maxf(280.0, speed * 1.35):
			e.worker_clip = "recover" if HordeWorkerSprite.idle_frame(float(e.worker_time)) >= 25 else "defesa"
			e.worker_time = 0.0

func update_woman_civil(e: Dictionary, dt: float) -> void :
	e.woman_time = float(e.woman_time) + dt
	var clip: String = str(e.woman_clip)
	if clip == "idle":
		var lead: int = leader_index()
		if lead >= 0 and float(members[lead].x) < float(e.x) and float(e.x) - float(members[lead].x) < maxf(392.0, speed * 1.6):
			e.woman_clip = "startle";e.woman_time = 0.0;e.pose = "panic"
	elif clip == "startle":
		if float(e.woman_time) >= 0.36:
			e.vx = move_toward(float(e.vx), float(e.flee_speed), dt * 380.0)
		if float(e.woman_time) >= 1.0:
			e.woman_clip = "run";e.woman_time = 0.0;e.pose = "run"
	else:
		e.vx = move_toward(float(e.vx), float(e.flee_speed), dt * 380.0)
	if not civilian_floor_safe(float(e.x) + float(e.vx) * 0.4, 42.0):
		e.x -= maxf(0.0, float(e.vx)) * dt;e.vx = 0.0

func update_blue_civil(e: Dictionary, dt: float) -> void :
	e.civil_time += dt;e.civil_turn_left = maxf(0, float(e.civil_turn_left) - dt)
	var clip = str(e.civil_clip)
	if clip == "parado_nervoso":
		var lead = leader_index()
		if lead >= 0 and float(members[lead].x) < float(e.x) and float(e.x) - float(members[lead].x) < maxf(392, speed * 1.6):
			e.civil_clip = "susto_inicio_fuga";e.civil_time = 0.0
	elif clip == "susto_inicio_fuga":
		if HordeCivilSprite.sample(clip, e.civil_time) >= 6:
			civil_turn(e, false);e.vx = move_toward(e.vx, e.flee_speed, dt * 380)
		if float(e.civil_time) >= 1.08: e.civil_time -= 1.08;e.civil_clip = "transicao_susto_corrida"
	else:
		e.vx = move_toward(e.vx, e.flee_speed, dt * 380)
		if clip == "transicao_susto_corrida" and float(e.civil_time) >= 0.12:
			e.civil_time -= 0.12;e.civil_clip = "corrida"
	if not civilian_floor_safe(float(e.x) + float(e.vx) * 0.4, 42):
		e.x -= maxf(0, float(e.vx)) * dt;e.vx = 0.0

func tutorial_hints() -> bool:
	return tutorial_enabled and developer_kind.is_empty() and entered_tunnels == 0

func configure_vehicle(entity: Dictionary) -> void :


	if entity.taken or not MonsterCatalog.VEHICLES.has(entity.kind): return
	entity.reinforced = false
	entity.required_count = int(MonsterCatalog.VEHICLES[entity.kind].need)

func configure_items(active: Dictionary, rare: bool) -> void:
	run_items = active.duplicate();rare_pending = rare
	if active.has("power_shield"): shields = maxi(shields,1)
	if active.has("power_boost"): boost_left = HordeTuning.BOOST_SECONDS;mark_power_collected();bonuses += 1
	if active.has("power_harvester"): blessings.begin(self,5)
	elif active.has("power_spectral"): blessings.begin(self,6)
	opening_power = 3 if active.has("power_fly") else 2 if active.has("power_mask") else -1
	# A prize grants a single-run use without changing permanent ownership in the save.
	if opening_power >= 0 and opening_power not in power_owned: power_owned.append(opening_power)
	if active.has("double_horde"):
		var initial = members.size()
		for i in range(initial): add_member(recruit_kind(), false)
	if active.has("civil_pack"):
		spawn_civilians(1200.0, 3, next_entity_id + 9000000)

func update_meta_run() -> void:
	if opening_power >= 0 and elapsed >= 1.2 and not dead and transform_left <= 0:
		var kind = opening_power;opening_power = -1;grant_perk(kind)
	if not rare_pending or elapsed < 8.0: return
	var start = ANCHOR + 560.0
	var clear = terrain.safe_span(world_px + start - 60, world_px + start + 380, 30)
	for e in entities:
		if not e.taken and e.kind not in ["coin", "civilian", "eye"] and e.x + float(e.width) > start - 100 and e.x < start + 440: clear = false
	if not clear: return
	for i in range(5):
		var x = start + i * 64
		add_entity("eye", x, ground_y(x) - 70 - sin(i * PI / 4) * 55, 0, 28)
	rare_pending = false

func update_projectile_impacts() -> void:
	for e in entities.duplicate():
		if e.taken: continue
		if e.kind == "soldier_blast":
			if float(e.age) > 0.45: e.taken = true
			continue
		if e.kind != "bullet" or str(e.get("shot_mode", "")) != "rocket": continue
		var impact = e.y >= ground_y(e.x) - 4 and e.x > view_left
		for obstacle in entities:
			if not obstacle.taken and MonsterCatalog.VEHICLES.has(obstacle.kind):
				if HordeBalance.surface(obstacle).has_point(Vector2(e.x, e.y)): impact = true;break
		if impact: soldier.explode(self, e)

func revive_horde(count: int) -> void:
	dead = false;members.clear();cached_active = -1
	perk_left = 0;perk_kind = -1;transform_left = 0;boost_left = 0
	for e in entities:
		if e.x + float(e.width) < ANCHOR - 400 or e.x > ANCHOR + maxf(1000, speed * 3.0): continue
		if e.kind not in ["coin", "eye"]: e.taken = true
	rebuild_surfaces()
	for i in range(count): add_member(recruit_kind(), false)
	hit_grace = 3.0;recovery_left = 3.0;recovery_speed = 275.0
	for m in members: m.y = ground_y(m.x);m.vy = 0.0;m.falling = false
	events.clear()
