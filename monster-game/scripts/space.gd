extends RefCounted
## Abdução Maldita. The road keeps advancing while its collisions are suspended.
## A separate power preserves the real monster identities and their cosmetics.

const POWER = 4
const ANCHOR = MonsterCatalog.ANCHOR
const FLOOR = 574.0
const ASCENT_SECONDS = 2.6
const RETURN_SECONDS = 2.4
const CELL = 256.0
const ZONES = ["ÓRBITA DA TERRA", "CEMITÉRIO ORBITAL", "NINHO DO PASSAGEIRO", "HORIZONTE PERDIDO"]
var active = false
var phase = "ground"
var age = 0.0
var flight_age = 0.0
var phase_age = 0.0
var duration = 30.0
var left = 0.0
var altitude = 0.0
var max_altitude = 0.0
var y = 440.0
var vy = 0.0
var hurt_left = 0.0
var hit_cooldown = 0.0
var thrust_flash = 0.0
var start_world = 0.0
var start_tunnel = 0
var last_zone = -1
var next_group = 0.0
var group_serial = 0
var completed_flights = 0
var early_offered = false
var warning_second = 6
var captured = 0
var collected = 0
var hits = 0
var discoveries: Dictionary = {}
var objects: Array[Dictionary] = []
var starts: Dictionary = {}
var random = RandomNumberGenerator.new()
var textures: Dictionary = {}
var tiles: Dictionary = {}

func reset(seed_value: int) -> void:
	active = false;phase = "ground";objects.clear();starts.clear();discoveries.clear()
	age = 0;flight_age = 0;phase_age = 0;altitude = 0;max_altitude = 0
	completed_flights = 0;early_offered = false;captured = 0;collected = 0;hits = 0
	random.seed = seed_value ^ 0x51ace

func seconds(level: int) -> float:
	return 30.0 + clampi(level, 0, 3) * 10.0

func zone() -> int:
	return 3 if altitude >= 3100 else 2 if altitude >= 1900 else 1 if altitude >= 850 else 0

func blend() -> float:
	if not active: return 0.0
	if phase == "ascent": return smoothstep(0.1, ASCENT_SECONDS - 0.1, phase_age)
	if phase == "return": return 1.0 - smoothstep(0.15, RETURN_SECONDS - 0.15, phase_age)
	return 1.0

func begin(r, force: bool = false) -> bool:
	if active or r.dead or r.active_count() <= 0: return false
	if not force and (POWER not in r.power_owned or not r.power_eligible()): return false
	if force:
		r.perk_left = 0;r.perk_kind = -1;r.boost_left = 0;r.transform_left = 0
	# Finish captures already earned before the beam takes the party away.
	for e in r.entities:
		if e.state == "capture" and e.kind in ["civilian", "police", "soldier"]: r.complete_capture(e)
	for i in range(r.members.size() - 1, -1, -1):
		if r.members[i].falling: r.remove_member(i, "fall")
	active = true;phase = "ascent";age = 0;phase_age = 0;flight_age = 0
	duration = seconds(int(r.power_levels.get("space_time", 0)));left = duration
	altitude = 0;y = 420;vy = 0;hurt_left = 0;hit_cooldown = 0;thrust_flash = 0
	next_group = 0.4;group_serial = 0;last_zone = -1;warning_second = 6
	start_world = r.world_px;start_tunnel = r.tunnel_number()
	starts.clear();objects.clear();discoveries.clear()
	for m in r.members:
		starts[int(m.id)] = Vector2(m.x, m.y)
		m.jump_queue.clear();m.jump_at = -1.0;m.jump_delay = -1.0;m.vy = 0.0;m.roof_id = -1
	r.jump_buffer_until = -1;r.wave_holds.clear();r.wave_durations.clear();r.wave_started.clear()
	r.mark_power_collected();r.bonuses += 1;r.flights += 1
	r.mission_stats.space_flights = int(r.mission_stats.get("space_flights", 0)) + 1
	r.events.append({"type":"space_begin","duration":duration})
	return true

func offer_test_pickup(r) -> void:
	if active or early_offered or r.elapsed < 7.0 or POWER not in r.power_owned: return
	if not bool(ProjectSettings.get_setting("testing/space_early_pickup_enabled", false)): return
	if not r.developer_kind.is_empty() or not r.power_eligible() or r.bonus_director.active(r): return
	for step in range(14):
		var at = r.spawn_left() + 90.0 + step * 90.0
		if not r.bonus_director.safe(r, at): continue
		var e = r.add_entity("space_brain", at - r.world_px, r.terrain.floor_at(at) - 66.0)
		e.bonus_world = at;early_offered = true
		r.bonus_director.last_opportunity = at
		r.bonus_director.reschedule(at, maxf(305.0, r.cruise_speed))
		return

func impulse() -> void:
	if active and phase == "flight": vy = minf(vy, -175.0);thrust_flash = 0.28

func _world_step(r, dt: float) -> void:
	var target = HordeDirector.stage_speed(r.tunnel_number()) * 1.42
	r.cruise_speed = move_toward(r.cruise_speed, target, dt * 90.0)
	r.time_scale = move_toward(r.time_scale, 1.0, dt * 1.4)
	r.speed = r.cruise_speed * r.time_scale;r.last_effective_speed = r.speed
	var step = r.speed * dt
	r.world_px += step
	r.terrain.reserve(r, r.world_px + r.generation_horizon() + 3000, r.speed)
	r.update_tunnels()
	for e in r.entities: e.x -= step
	for i in range(r.entities.size() - 1, -1, -1):
		if r.entities[i].x < r.view_left - 400: r.entities.remove_at(i)
	if r.tunnel_number() != r.last_tunnel:
		r.last_tunnel = r.tunnel_number();r.events.append({"type":"tunnel","area":r.area(),"number":r.last_tunnel})
	if r.area() != r.last_area:
		r.last_area = r.area()
	r.mission_stats.space_distance = maxi(int(r.mission_stats.get("space_distance", 0)), int((r.world_px - start_world) / 30.0))
	r.hit_grace = maxf(0, r.hit_grace - dt)

func advance(r, dt: float, held: bool) -> void:
	if not active: return
	age += dt;phase_age += dt;_world_step(r, dt)
	hurt_left = maxf(0, hurt_left - dt);hit_cooldown = maxf(0, hit_cooldown - dt);thrust_flash = maxf(0, thrust_flash - dt)
	if phase == "ascent":
		_update_members(r, dt)
		if phase_age >= ASCENT_SECONDS:
			phase = "flight";phase_age = 0
			r.events.append({"type":"space_zone","zone":0,"title":ZONES[0]})
			last_zone = 0
		return
	if phase == "return":
		_update_members(r, dt)
		if phase_age >= RETURN_SECONDS: finish(r)
		return
	flight_age += dt;left = maxf(0, left - dt)
	altitude += dt * (75.0 if held else 50.0);max_altitude = maxf(max_altitude, altitude)
	r.mission_stats.space_altitude = maxi(int(r.mission_stats.get("space_altitude", 0)), int(altitude))
	var target_vy = -155.0 if held else 118.0
	vy = move_toward(vy, target_vy, dt * 650.0)
	if zone() == 3: vy += clampf((425.0 - y) * 0.22, -34.0, 34.0) * dt
	var top = 295.0
	y = clampf(y + vy * dt, top, 558.0)
	if zone() != last_zone:
		last_zone = zone();r.events.append({"type":"space_zone","zone":last_zone,"title":ZONES[last_zone]})
		_spawn_discovery(r, last_zone)
	_update_members(r, dt)
	next_group -= dt
	if next_group <= 0:
		spawn_group(r);next_group = random.randf_range(1.25, 1.7)
	_update_objects(r, dt)
	var remaining = ceili(left)
	if remaining <= 5 and remaining < warning_second and remaining > 0:
		warning_second = remaining;r.events.append({"type":"space_warning","seconds":remaining})
	if left <= 0:
		phase = "return";phase_age = 0
		for m in r.members: starts[int(m.id)] = Vector2(m.x, m.y)
		r.events.append({"type":"space_return","tunnels":maxi(0, r.completed_tunnels - start_tunnel + 1)})

func _update_members(r, dt: float) -> void:
	var columns = 8 if r.members.size() > 12 else 6
	for i in range(r.members.size()):
		var m = r.members[i]
		var column = i % columns;var row = int(i / columns)
		var x = maxf(r.view_left + 44, ANCHOR - column * 43.0 - row * 11.0)
		var wave = sin(age * 2.9 - column * 0.48 + row * 0.7) * 11.0
		var target_y = clampf(y + row * 23.0 + wave, 230, 585)
		if phase == "ascent":
			var from = starts.get(int(m.id), Vector2(m.x, m.y))
			var t = smoothstep(0.1 + column * 0.05, ASCENT_SECONDS - 0.1, phase_age)
			m.x = lerpf(from.x, x, t);m.y = lerpf(from.y, target_y, t)
		elif phase == "return":
			var from = starts.get(int(m.id), Vector2(m.x, m.y))
			var t = smoothstep(0.0, RETURN_SECONDS - 0.15, phase_age)
			m.x = lerpf(from.x, x, t);m.y = lerpf(from.y, r.ground_y(x), t)
		else:
			m.x = move_toward(m.x, x, dt * 155.0)
			m.y = lerpf(float(m.y), target_y, 1.0 - exp(-dt * (7.0 - minf(column * 0.35, 2.0))))
		m.vy = vy;m.air_time += dt;m.run_phase += dt * 0.65;m.air_pose = 1.0
		m.hurt_left = maxf(0, m.hurt_left - dt);m.attack_left = maxf(0, m.attack_left - dt)
		m.push_left = 0;m.land_left = 0;m.arrival = 0;m.falling = false

func add_object(kind: String, x: float, at_y: float, extra: Dictionary = {}) -> Dictionary:
	var e = {"kind":kind,"x":x,"y":at_y,"base_y":at_y,"age":0.0,"angle":random.randf_range(-0.2,0.2),"spin":random.randf_range(-0.65,0.65),"seed":random.randf_range(0,TAU),"state":"normal","taken":false,"radius":30.0,"variant":0,"speed":1.0}
	e.merge(extra,true);objects.append(e);return e

func spawn_group(r) -> void:
	group_serial += 1
	var right = r.view_right + 110.0
	var lane = random.randf_range(265, 490)
	# One clearly readable collectible arc, with hazards on a separate lane.
	for j in range(6):
		add_object("coin", right + j * 52.0, lane + sin(j * 0.65) * 35.0, {"radius":25.0})
	if group_serial % 3 == 1:
		add_object("astronaut", right + 220, clampf(y - 55 + random.randf_range(-65,65), 210, 510), {"radius":42.0,"speed":0.76})
	if group_serial % 2 == 0:
		var hazard_y = clampf(lane + (155.0 if lane < 365 else -155.0), 205, 550)
		add_object("meteor", right + 180, hazard_y, {"radius":37.0,"variant":random.randi_range(0,2),"speed":1.15})
	if group_serial % 5 == 0:
		add_object("energy", right + 330, lane, {"radius":32.0})
	if zone() >= 1 and group_serial % 4 == 0:
		add_object("satellite", right + 410, 530 if lane < 370 else 215, {"radius":43.0,"speed":0.68})
	if zone() >= 2 and group_serial % 3 == 0:
		add_object("parasite", right + 340, random.randf_range(250,480), {"radius":37.0,"speed":0.9})
	if group_serial % 4 == 2:
		add_object("coffin", right + 470, 565, {"speed":0.45,"radius":30.0})
	if objects.size() > 110: objects = objects.slice(objects.size() - 110)

func _spawn_discovery(r, layer: int) -> void:
	if discoveries.has(layer): return
	discoveries[layer] = true
	var right = r.view_right + 90
	if layer == 1: add_object("pod", right, 400, {"speed":0.48,"radius":44.0})
	if layer == 2:
		add_object("egg", right + 170, 390, {"speed":0.55,"radius":39.0})
		r.events.append({"type":"space_discovery","title":"UM PASSAGEIRO A MAIS..."})
	if layer == 3:
		add_object("ghost_ship", right + 350, 270, {"speed":0.25,"radius":60.0})
		add_object("monolith", right + 190, 430, {"speed":0.65,"radius":39.0})
		r.events.append({"type":"space_discovery","title":"HORIZONTE PERDIDO • SINAL DESCONHECIDO"})

func _update_objects(r, dt: float) -> void:
	var lead_index = r.leader_index()
	if lead_index < 0: return
	var leader = r.members[lead_index]
	var centre = Vector2(leader.x, leader.y - 57)
	for e in objects:
		e.age += dt;e.x -= r.speed * float(e.speed) * dt;e.angle += e.spin * dt
		e.y = e.base_y + sin(e.age * 2.0 + e.seed) * (9 if e.kind != "coin" else 3)
		if e.state == "capture":
			e.x = lerpf(float(e.x), centre.x + 25, minf(1, dt * 7))
			e.y = lerpf(float(e.y), centre.y - 5, minf(1, dt * 7));e.base_y = e.y
			if e.age >= 0.72:
				e.taken = true;captured += 1;r.souls += 1;r.recruits += 1
				r.mission_stats.civilians = int(r.mission_stats.get("civilians",0)) + 1
				r.mission_stats.space_captures = int(r.mission_stats.get("space_captures",0)) + 1
				var kind = r.recruit_kind();r.add_member(kind, false, Vector2(leader.x - 50, leader.y))
				r.events.append({"type":"soul","kind":kind,"x":centre.x,"y":centre.y,"soldier":false,"from_vehicle":false})
			continue
		if e.taken: continue
		var p = Vector2(e.x,e.y)
		if e.kind == "parasite" and e.x - centre.x < 370:
			e.state = "attack";e.base_y = move_toward(e.base_y, centre.y, dt * 24)
		if e.kind == "egg" and e.age > 2.0 and e.state == "normal":
			e.state = "open"
			# The egg's opening is visual; the approaching parasite has its own warning time.
		var reach = float(e.radius) + (58.0 if e.kind == "coin" else 23.0)
		if centre.distance_to(p) >= reach: continue
		match e.kind:
			"coin":
				e.taken = true;r.coins += 2;collected += 2
				r.events.append({"type":"coin","amount":2,"x":e.x,"y":e.y,"physical_pickup":true,"frenzy_pickup":false})
			"energy":
				e.taken = true;left = minf(duration + 8.0 - flight_age, left + 1.5)
				r.events.append({"type":"space_energy","x":e.x,"y":e.y})
			"astronaut", "pod":
				e.state = "capture";e.age = 0.0
				leader.attack_left = 0.72;leader.attack_duration = 0.72
				r.events.append({"type":"space_capture","x":e.x,"y":e.y})
			"monolith":
				e.taken = true;r.coins += 40
				r.events.append({"type":"coin","amount":40,"x":e.x,"y":e.y})
				r.events.append({"type":"space_discovery","title":"2001 ALMAS • ENCONTRO COM O MONÓLITO"})
			"meteor", "satellite", "parasite", "egg":
				if hit_cooldown <= 0:
					e.taken = true;hit_cooldown = 1.15;hurt_left = 0.55;hits += 1
					left = maxf(0, left - 2.5);leader.hurt_left = 0.55
					r.events.append({"type":"space_hit","x":e.x,"y":e.y})
	for i in range(objects.size() - 1,-1,-1):
		if objects[i].taken or objects[i].x < r.view_left - 400: objects.remove_at(i)

func finish(r) -> void:
	active = false;phase = "ground";left = 0;completed_flights += 1
	# All pending astronaut captures count before the party lands.
	for e in objects:
		if e.state == "capture" and not e.taken:
			r.souls += 1;r.recruits += 1;captured += 1
			r.mission_stats.civilians = int(r.mission_stats.get("civilians",0)) + 1
			r.mission_stats.space_captures = int(r.mission_stats.get("space_captures",0)) + 1
			var kind = r.recruit_kind();r.add_member(kind,false)
			r.events.append({"type":"soul","kind":kind,"x":ANCHOR,"y":FLOOR - 70,"soldier":false,"from_vehicle":false})
	objects.clear();starts.clear()
	r.entities.clear();r.physics_surfaces.clear();r.physics_gaps.clear()
	var safe_end = r.world_px + r.generation_horizon() + 2400
	r.terrain.segments.assign([{"start":r.world_px - 100000.0,"end":safe_end,"height":0.0,"state":HordeTerrain.State.NORMAL}])
	r.terrain.generated_to = safe_end;r.terrain.state = HordeTerrain.State.NORMAL
	r.next_pattern_world = r.world_px + r.view_right + r.speed * 3.0 + 500
	r.next_segment = maxi(r.next_segment, 1)
	r.recovery_left = 2.5;r.recovery_speed = HordeDirector.stage_speed(r.tunnel_number())
	r.hit_grace = 2.2;r.jump_buffer_until = -1;r.cached_active = -1
	for i in range(r.members.size()):
		var m = r.members[i];m.x = r.slot_x(i);m.y = r.ground_y(m.x);m.vy = 0.0
		m.air_time = 0.0;m.air_pose = 0.0;m.air_jumps = 0;m.roof_id = -1;m.land_left = 0.24
		m.attack_left = 0;m.hurt_left = 0;m.jump_queue.clear();m.jump_at = -1;m.jump_delay = -1
	r.bonus_director.collected(r)
	r.events.append({"type":"space_land","from_tunnel":start_tunnel,"to_tunnel":r.tunnel_number(),"metres":int((r.world_px - start_world) / 30)})

func ensure_art() -> void:
	if not textures.is_empty(): return
	for key in ["npcs", "props", "orbit", "nebula"]:
		var path = "res://assets/art/space_v130/" + key + (".webp" if key in ["orbit","nebula"] else ".png")
		var image = Image.load_from_file(path)
		if image == null: push_error("Missing space art: " + path);continue
		textures[key] = ImageTexture.create_from_image(image)
	for key in ["npcs", "props"]:
		if not textures.has(key): continue
		tiles[key] = []
		for index in range(16):
			var tile = AtlasTexture.new();tile.atlas = textures[key];tile.filter_clip = true
			tile.region = Rect2((index % 4) * CELL, int(index / 4) * CELL, CELL, CELL)
			tiles[key].append(tile)

func sprite(canvas, key: String, frame: int, point: Vector2, height: float, angle: float = 0.0, tint: Color = Color.WHITE, flip: bool = false) -> void:
	ensure_art()
	if not tiles.has(key): return
	canvas.draw_set_transform(point,angle,Vector2(-1 if flip else 1,1))
	canvas.draw_texture_rect(tiles[key][posmod(frame,16)],Rect2(Vector2.ONE * -height * 0.5,Vector2.ONE * height),false,tint)
	canvas.draw_set_transform(Vector2.ZERO)

func paint_pickup(g, point: Vector2, height: float = 84.0, label: bool = true) -> void:
	var c = g.paint_target;var t = g.ui_time
	c.draw_circle(point, height * 0.65, Color(0.35,1,0.63,0.06 + sin(t * 3) * 0.02))
	c.draw_arc(point, height * 0.58, t * 1.2, t * 1.2 + TAU * 0.74,32,Color(0.45,1,0.64,0.55),2.4,true)
	sprite(c,"props",2 + posmod(int(t * 3),2),point,height * 1.18,sin(t * 2) * 0.04)
	if label: g.text("ESPAÇO • " + str(int(seconds(int(g.data.power_levels.get("space_time",0))))) + " s",point + Vector2(0,-height * 0.77),15,g.MINT,true,true,2)

func paint_background(g) -> void:
	ensure_art()
	var c = g.paint_target;var r = g.runner
	var rect = Rect2(g.scenery.view_left,g.scenery.view_top,g.scenery.view_right - g.scenery.view_left,g.scenery.view_bottom - g.scenery.view_top)
	var alpha = blend();var deep = smoothstep(650,1800,altitude)
	for key in ["orbit","nebula"]:
		if not textures.has(key): continue
		var texture = textures[key];var scale = maxf((rect.size.x + 100) / texture.get_width(),(rect.size.y + 65) / texture.get_height())
		var size = texture.get_size() * scale
		var drift = Vector2(sin(age * 0.045) * 24, sin(age * 0.06) * 10)
		var destination = Rect2(rect.get_center() - size * 0.5 + drift,size)
		c.draw_texture_rect(texture,destination,false,Color(1,1,1,alpha * (1 if key == "orbit" else deep)))
	if alpha <= 0: return
	for i in range(76):
		var depth = 0.15 + float(i % 4) * 0.24
		var x = rect.position.x + fposmod(i * 157.37 - r.world_px * depth * 0.12,rect.size.x)
		var sy = rect.position.y + fposmod(i * 83.71 + altitude * depth * 0.055,rect.size.y)
		var twinkle = 0.35 + 0.35 * sin(age * (0.5 + depth) + i)
		var color = Color(0.65,0.95,1,alpha * twinkle)
		c.draw_circle(Vector2(x,sy),0.8 + depth * 1.3,color)
		if i % 7 == 0: c.draw_line(Vector2(x,sy),Vector2(x + 10 + depth * 20,sy - 3),Color(color,alpha * 0.15),1,true)
	if altitude > 2600: _paint_black_hole(g,rect,alpha * smoothstep(2600,3300,altitude))

func _paint_black_hole(g, rect: Rect2, alpha: float) -> void:
	var c = g.paint_target;var point = rect.position + rect.size * Vector2(0.77,0.36)
	var radius = minf(95,rect.size.y * 0.16)
	for i in range(12,-1,-1):
		c.draw_circle(point,radius + i * 5.0,Color(0.5,0.15,0.95,alpha * 0.008 * (13 - i)))
	for layer in range(4):
		var points = PackedVector2Array()
		for j in range(81):
			var a = j * TAU / 80.0 + age * (0.3 + layer * 0.12)
			var radius_here = radius + 19 + sin(a * 3 + age * 1.4) * 4 + layer * 7
			points.append(point + Vector2(cos(a) * radius_here * 1.7,sin(a) * radius_here * 0.38))
		c.draw_polyline(points,Color(0.45 + layer * 0.12,0.25 + layer * 0.14,1,alpha * 0.6),3.5,true)
	c.draw_circle(point,radius,Color(0.004,0.002,0.014,alpha))
	c.draw_arc(point,radius + 1,0,TAU,80,Color(0.82,0.64,1,alpha * 0.9),2.0,true)
	for i in range(4):
		var a = age * 0.7 + i * TAU / 4
		c.draw_arc(point,radius + 6 + sin(age * 2 + i) * 3,a,a + 0.6,20,Color(0.7,1,0.8,alpha * 0.65),3,true)

func paint(g) -> void:
	var r = g.runner;var c = g.paint_target
	ensure_art()
	if phase in ["ascent","return"]:
		var centre = Vector2(ANCHOR - 40, 195 + sin(age * 3) * 4)
		var pulse = 0.16 + sin(age * 8) * 0.035
		var points = PackedVector2Array([centre + Vector2(-60,25),centre + Vector2(65,25),Vector2(centre.x + 240,FLOOR),Vector2(centre.x - 240,FLOOR)])
		c.draw_colored_polygon(points,Color(0.4,1,0.6,pulse))
		for line in range(7):
			var sy = 225 + fposmod(age * -185 + line * 58,350)
			c.draw_arc(Vector2(centre.x,sy),50 + (sy - 220) * 0.45,0,PI,28,Color(0.55,1,0.7,0.25),2.4,true)
		sprite(c,"props",1,centre,260)
	var object_alpha = blend() if phase == "return" else 1.0
	var object_tint = Color(1,1,1,object_alpha)
	for e in objects:
		var point = Vector2(e.x,e.y);var t = float(e.age)
		match e.kind:
			"coin": g.scenery.sprite(c,g.art.items[1],point,31,object_tint,sin(t * 6) * 0.2)
			"energy": sprite(c,"props",2 + posmod(int(t * 4),2),point,62,sin(t * 3) * 0.08,object_tint)
			"astronaut":
				var frame = (4 if e.state == "capture" or e.x < ANCHOR + 260 else 0) + posmod(int(t * 8),4)
				var fade = 1.0 - smoothstep(0.4,0.72,t) if e.state == "capture" else 1.0
				sprite(c,"npcs",frame,point,116,sin(t * 2) * 0.09,Color(1,1,1,fade * object_alpha))
			"parasite":
				sprite(c,"npcs",(12 if e.state == "attack" else 8) + posmod(int(t * 9),4),point,117,sin(t * 3) * 0.08,object_tint,true)
				if e.x > r.view_right - 150: _warning(g,point,Color("ffa67d"))
			"meteor":
				var points = PackedVector2Array([point + Vector2(18,-20),point + Vector2(115,-48),point + Vector2(66,-3),point + Vector2(150,10),point + Vector2(12,24)])
				c.draw_colored_polygon(points,Color(1,0.34,0.08,(0.2 + sin(t * 10) * 0.05) * object_alpha))
				sprite(c,"props",4 + int(e.variant),point,111,e.angle,object_tint)
			"satellite": sprite(c,"props",8 + posmod(int(t * 2),2),point,146,e.angle * 0.4,object_tint)
			"coffin": sprite(c,"props",7,point,88,e.angle,object_tint)
			"pod": sprite(c,"props",10 + posmod(int(t * 3),2),point,117,sin(t * 2) * 0.1,object_tint)
			"egg": sprite(c,"props",15 if e.state == "open" else 14,point,112,sin(t * 2) * 0.035,object_tint)
			"ghost_ship":
				sprite(c,"props",12 + posmod(int(t * 1.6),2),point,330,sin(t * 0.4) * 0.035,Color(0.7,0.8,1,0.76 * object_alpha))
			"monolith":
				c.draw_set_transform(point,sin(t * 0.5) * 0.14)
				c.draw_rect(Rect2(-15,-48,30,96),Color(Color("080810"),object_alpha))
				c.draw_line(Vector2(-15,-48),Vector2(-15,48),Color(Color("9c84d6"),object_alpha),2)
				c.draw_circle(Vector2(0,-26),2.5,Color(Color("ff796e"),object_alpha));c.draw_set_transform(Vector2.ZERO)
	var visible = HordeCrowdVisibility.visible(r);g.crowd_drawn = visible.size()
	var order = visible.keys();order.reverse()
	for i in order:
		var m = r.members[i];var foot = Vector2(m.x,m.y)
		var state = "capture" if m.attack_left > 0 else ("fall" if phase == "return" else "fly")
		var anim_phase = (0.72 - m.attack_left) / 0.72 if m.attack_left > 0 else m.run_phase
		var tint = Color(1,0.65,0.65,1) if hurt_left > 0 and int(age * 15) % 2 == 0 else Color.WHITE
		g.actor.paint(c,int(m.kind),foot,112,anim_phase,state,r.elapsed + i * 0.073,0,tint,false,1,true,0.45,vy,r.cosmetics_for(m,int(m.kind)))
		if phase == "flight" and thrust_flash > 0:
			c.draw_arc(foot + Vector2(0,4),19,0,PI,12,Color(0.5,1,0.65,thrust_flash),2,true)
	if phase == "return":
		var t = smoothstep(1.4,RETURN_SECONDS,phase_age)
		c.draw_arc(Vector2(ANCHOR,FLOOR),35 + t * 100,PI,TAU,48,Color(0.5,1,0.65,t * 0.8),4,true)

func _warning(g, point: Vector2, color: Color) -> void:
	var c = g.paint_target
	c.draw_arc(point,54,-0.7,0.7,16,Color(color,0.65 + sin(age * 8) * 0.15),2,true)

func paint_hud(g) -> void:
	var r = g.runner;var view = g.full_rect()
	var rect = Rect2(view.end.x - 425,view.position.y + 20,308,78)
	g.home_menu.slab(g,rect,Color("263047"),g.MINT,12,3)
	sprite(g,"props",2,rect.position + Vector2(36,39),61)
	g.home_menu.label(g,"ABDUÇÃO MALDITA",rect.position + Vector2(71,26),19,g.MINT,false,224)
	var label = "SUBINDO..." if phase == "ascent" else "REENTRADA" if phase == "return" else str(ceili(left)) + " s  •  " + str(int(altitude)) + " km"
	g.home_menu.label(g,label,rect.position + Vector2(71,53),20,g.CREAM,false,225)
	var bar = Rect2(rect.position + Vector2(72,63),Vector2(215,6))
	g.draw_rect(bar,Color("172036"));bar.size.x *= clampf(left / duration,0,1);g.draw_rect(bar,g.MINT if left > 5 else g.CORAL)
	var top = view.position.y + 139
	g.home_menu.slab(g,Rect2(view.get_center().x - 215,top,430,43),Color(0.12,0.08,0.22,0.88),Color("69568d"),12,2)
	g.home_menu.label(g,ZONES[zone()] if phase == "flight" else "A CORRIDA CONTINUA LÁ EMBAIXO",Vector2(view.get_center().x,top + 29),20,g.GOLD,true,410)
	var bottom = view.end.y - 48
	if phase == "flight":
		g.home_menu.label(g,"SEGURE PARA SUBIR • SOLTE PARA DESCER • IMPACTOS: −2,5 s",Vector2(view.get_center().x,bottom),18,g.CREAM,true,view.size.x - 100)
	if g.lab_active and g.lab_kind == "space":
		g.button(Rect2(view.position.x + 25,view.end.y - 110,220,43),"RECOMEÇAR VOO","lab_space_restart",Color("4c786a"),-2,17)
		g.button(Rect2(view.position.x + 260,view.end.y - 110,220,43),"TEMPO: " + str(int(duration)) + " s","lab_space_time",Color("513c67"),-2,17)
		g.button(Rect2(view.position.x + 495,view.end.y - 110,230,43),"SUBIR UMA CAMADA","lab_space_zone",Color("513c67"),-2,17)
		g.button(Rect2(view.end.x - 245,view.end.y - 110,220,43),"POUSAR AGORA","lab_space_land",Color("513c67"),-2,17)
