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
static var textures: Dictionary = {}
var tiles: Dictionary = {}
var battle = preload("res://scripts/space_combat.gd").new()
var charge = 0.0
var wave_number = 1
var dash_left = 0.0
var dash_cooldown = 0.0
var dash_serial = 0
var aim_y = 420.0
var manual_control = false
var boost_from = 0.0
var boost_to = 0.0
var return_prepared = false
var y_history: Array[Vector2] = []

func reset(seed_value: int) -> void:
	active = false;phase = "ground";objects.clear();starts.clear();discoveries.clear()
	age = 0;flight_age = 0;phase_age = 0;altitude = 0;max_altitude = 0
	battle.reset();charge = 0;wave_number = 1;dash_left = 0;dash_cooldown = 0;y_history.clear()
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
	battle.reset();charge = 0;wave_number = 1;dash_left = 0;dash_cooldown = 0;dash_serial = 0;aim_y = 420;manual_control = false;return_prepared = false;y_history.clear()
	if force:
		for kind in [7,8]:
			if kind not in r.power_owned: r.power_owned.append(kind)
	ensure_art();battle.art.warm()
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
	var multiplier = lerpf(1.42,1.0,smoothstep(0,RETURN_SECONDS,phase_age)) if phase == "return" else 1.42
	var target = HordeDirector.stage_speed(r.tunnel_number()) * multiplier
	r.cruise_speed = move_toward(r.cruise_speed, target, dt * 90.0)
	r.time_scale = move_toward(r.time_scale, 1.0, dt * 1.4)
	r.speed = r.cruise_speed * r.time_scale;r.last_effective_speed = r.speed
	var step = r.speed * dt
	r.world_px += step
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

func dash() -> bool:
	if not active or phase!="flight" or dash_cooldown>0: return false
	dash_serial += 1;dash_left = .48;dash_cooldown = 1.15;thrust_flash = .4;return true

func drag_by(delta_y: float) -> void:
	manual_control = true;aim_y = clampf(aim_y+delta_y,285,550)

func boost(r) -> void:
	if phase!="flight": return
	charge = 0;phase = "boost";phase_age = 0;wave_number += 1
	boost_from = altitude;boost_to = [1100.0,2150.0,3400.0,4000.0][zone()]
	r.events.append({"type":"space_boost","x":ANCHOR,"y":y-50})

func prepare_landing(r) -> void:
	if return_prepared: return
	return_prepared = true
	var safe_end = r.world_px+r.generation_horizon()+r.speed*(RETURN_SECONDS+3)
	r.terrain.segments.assign([{"start":r.world_px-100000.0,"end":safe_end,"height":0.0,"state":HordeTerrain.State.NORMAL}])
	r.terrain.generated_to = safe_end;r.terrain.state = HordeTerrain.State.NORMAL

func advance(r, dt: float, held: bool) -> void:
	if not active: return
	age += dt;phase_age += dt;_world_step(r,dt)
	hurt_left = maxf(0,hurt_left-dt);hit_cooldown = maxf(0,hit_cooldown-dt);thrust_flash = maxf(0,thrust_flash-dt)
	dash_left = maxf(0,dash_left-dt);dash_cooldown = maxf(0,dash_cooldown-dt)
	if phase=="ascent":
		_update_members(r,dt)
		if phase_age>=ASCENT_SECONDS:
			phase = "flight";phase_age = 0;last_zone = 0;r.events.append({"type":"space_zone","zone":0,"title":ZONES[0]})
		return
	if phase=="return":
		prepare_landing(r);_update_members(r,dt)
		if phase_age>=RETURN_SECONDS: finish(r)
		return
	flight_age += dt;left = maxf(0,left-dt)
	if phase=="boost":
		altitude = lerpf(boost_from,boost_to,smoothstep(.25,1.25,phase_age))
		if phase_age>=1.25: phase = "flight";phase_age = 0
	else: charge = minf(100,charge+8.0*dt)
	max_altitude = maxf(max_altitude,altitude)
	r.mission_stats.space_altitude = maxi(int(r.mission_stats.get("space_altitude",0)),int(altitude))
	var target_vy = clampf((aim_y-y)*5.5,-215,215) if manual_control else (-150.0 if held else 110.0)
	vy = move_toward(vy,target_vy,dt*850)
	y = clampf(y+vy*dt,285,550)
	if zone()==3: y += clampf((425-y)*.15,-25,25)*dt
	if zone()!=last_zone:
		last_zone = zone();r.events.append({"type":"space_zone","zone":last_zone,"title":ZONES[last_zone]});_spawn_discovery(r,last_zone)
	_update_members(r,dt)
	next_group -= dt
	if next_group<=0 and phase=="flight":
		battle.spawn(self,r)
		next_group = maxf(1.35,2.8-zone()*.15-maxi(0,r.active_count()-12)*.025)
	battle.advance(self,r,dt)
	if r.dead: active = false;return
	if charge>=100 and phase=="flight": boost(r)
	var remaining = ceili(left)
	if remaining<=5 and remaining<warning_second and remaining>0: warning_second = remaining;r.events.append({"type":"space_warning","seconds":remaining})
	if left<=0:
		phase = "return";phase_age = 0;return_prepared = false
		for m in r.members: starts[int(m.id)] = Vector2(m.x,m.y)
		r.events.append({"type":"space_return","tunnels":maxi(0,r.completed_tunnels-start_tunnel+1)})

func _update_members(r, dt: float) -> void:
	y_history.append(Vector2(age,y))
	while y_history.size()>150: y_history.pop_front()
	for i in range(r.members.size()):
		var m = r.members[i];var row = r.member_lane(i)
		var x = r.slot_x(i)
		var lag = minf(.75,maxi(0,i-12)*.018)
		var follow_y = y
		for sample in y_history:
			if sample.x>=age-lag: follow_y = sample.y;break
		var target_y = clampf(follow_y+row*15+sin(age*2.2-i*.65)*4,245,575)
		if phase=="boost":
			if phase_age<.3: x = lerpf(x,ANCHOR,(1-smoothstep(.0,.3,phase_age))*.18)
			else: target_y -= sin(clampf((phase_age-.3)/.95,0,1)*PI)*42
		if dash_left>0: x += sin((1-dash_left/.48)*PI)*225
		if phase=="ascent":
			var from = starts.get(int(m.id),Vector2(m.x,m.y));var t = smoothstep(.1+(i%8)*.035,ASCENT_SECONDS-.1,phase_age)
			m.x = lerpf(from.x,x,t);m.y = lerpf(from.y,target_y,t)
		elif phase=="return":
			var from = starts.get(int(m.id),Vector2(m.x,m.y));var t = smoothstep(0,RETURN_SECONDS-.15,phase_age)
			m.x = lerpf(from.x,r.slot_x(i),t);m.y = lerpf(from.y,r.ground_y(r.slot_x(i)),t)
		else:
			m.x = move_toward(m.x,x,dt*(1100 if dash_left>0 else 235));m.y = lerpf(float(m.y),target_y,1-exp(-dt*8))
		m.vy = vy;m.air_time += dt;m.run_phase += dt*.55;m.air_pose = 1
		m.hurt_left = maxf(0,m.hurt_left-dt);m.attack_left = maxf(0,m.attack_left-dt)
		m.push_left = 0;m.land_left = 0;m.arrival = 0;m.falling = false

func add_object(kind: String, x: float, at_y: float, extra: Dictionary = {}) -> Dictionary:
	var e = {"kind":kind,"x":x,"y":at_y,"base_y":at_y,"age":0.0,"angle":random.randf_range(-0.2,0.2),"spin":random.randf_range(-0.65,0.65),"seed":random.randf_range(0,TAU),"state":"normal","taken":false,"radius":30.0,"variant":0,"speed":1.0}
	e.merge(extra,true);objects.append(e);return e

func spawn_group(r) -> void:
	battle.spawn(self,r)

func _spawn_discovery(r, layer: int) -> void:
	if discoveries.has(layer): return
	discoveries[layer] = true
	var right = r.view_right + 90
	if layer == 1: add_object("pod", right, 400, {"speed":0.48,"radius":44.0})
	if layer == 2:
		add_object("egg", right + 170, 390, {"speed":0.55,"radius":39.0})
		r.events.append({"type":"space_discovery","title":"UM PASSAGEIRO A MAIS..."})
	if layer == 3:
		battle.spawn_ship(self,r,"ghost_frigate",right+350,270)
		add_object("monolith", right + 190, 430, {"speed":0.65,"radius":39.0})
		r.events.append({"type":"space_discovery","title":"HORIZONTE PERDIDO • SINAL DESCONHECIDO"})

func _update_objects(r,dt: float) -> void:
	battle.advance(self,r,dt)

func finish(r) -> void:
	prepare_landing(r)
	active = false;phase = "ground";left = 0;completed_flights += 1
	r.cruise_speed = HordeDirector.stage_speed(r.tunnel_number());r.speed = r.cruise_speed;r.time_scale = 1;r.last_effective_speed = r.speed
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
	r.next_pattern_world = r.world_px + maxf(r.view_right,r.planning_right) + r.speed * 1.2 + 200
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
		var image = Image.new()
		var data = FileAccess.get_file_as_bytes(path)
		if key in ["orbit","nebula"]: image.load_webp_from_buffer(data)
		else: image.load_png_from_buffer(data)
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
		if battle.paint_object(g,self,e,object_alpha): continue
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
	battle.paint_party(g,self)
	var visible = HordeCrowdVisibility.visible(r);g.crowd_drawn = visible.size()
	var order = visible.keys();order.reverse()
	for i in order:
		var m = r.members[i];var foot = Vector2(m.x,m.y)
		if battle.pilot_left>0:
			if i>2: continue
			foot = Vector2(ANCHOR-35+i*33,y-30)
		var state = "capture" if m.attack_left > 0 else ("fall" if phase == "return" else "fly")
		var anim_phase = (0.72 - m.attack_left) / 0.72 if m.attack_left > 0 else m.run_phase
		var tint = Color(1,0.65,0.65,1) if hurt_left > 0 and int(age * 15) % 2 == 0 else Color.WHITE
		var pose = "board" if m.attack_left>0 else "hurt" if m.hurt_left>0 else "return" if phase=="return" else "charge" if phase=="boost" and phase_age<.3 else "launch" if phase=="boost" or dash_left>0 else "float"
		g.actor.paint_space(c,int(m.kind),foot,48 if battle.pilot_left>0 else 112,r.elapsed+i*.073,pose,vy,r.cosmetics_for(m,int(m.kind)),tint)
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
	var rect = Rect2(view.end.x-425,view.position.y+20,308,78)
	g.home_menu.slab(g,rect,Color("263047"),g.MINT,12,3)
	sprite(g,"props",2,rect.position+Vector2(36,39),61)
	g.home_menu.label(g,"ABDUÇÃO MALDITA",rect.position+Vector2(71,26),19,g.MINT,false,224)
	var note = "SUBINDO..." if phase=="ascent" else "REENTRADA" if phase=="return" else "%d s • %d km" % [ceili(left),int(altitude)]
	g.home_menu.label(g,note,rect.position+Vector2(71,53),20,g.CREAM,false,225)
	var timer = Rect2(rect.position+Vector2(72,63),Vector2(215,6));g.draw_rect(timer,Color("172036"));timer.size.x *= clampf(left/duration,0,1);g.draw_rect(timer,g.MINT if left>5 else g.CORAL)
	var top = view.position.y+139
	g.home_menu.slab(g,Rect2(view.get_center().x-255,top,510,57),Color(.12,.08,.22,.88),Color("69568d"),12,2)
	g.home_menu.label(g,ZONES[zone()] if phase not in ["ascent","return"] else "A CORRIDA CONTINUA LÁ EMBAIXO",Vector2(view.get_center().x,top+24),18,g.GOLD,true,490)
	var bar = Rect2(view.get_center().x-230,top+37,460,10);g.draw_rect(bar,Color("151021"));bar.size.x *= charge/100;g.draw_rect(bar,g.MINT)
	g.home_menu.label(g,"IMPULSO %d%% • ONDA %d" % [int(charge),wave_number],Vector2(view.get_center().x,top+75),16,g.MINT,true,460)
	if phase in ["flight","boost"]:
		var button_y = view.end.y-(174 if g.lab_active else 90)
		g.button(Rect2(view.end.x-245,button_y,220,54),"INVESTIDA" if dash_cooldown<=0 else "RECARGA %.1f" % dash_cooldown,"space_dash",Color("4c786a") if dash_cooldown<=0 else Color("513c67"),-2,20)
		g.home_menu.label(g,"ARRASTE PARA GUIAR • INVESTIDA QUEBRA NAVES • IMPACTOS CUSTAM MEMBROS",Vector2(view.get_center().x,view.end.y-24),16,g.CREAM,true,view.size.x-50)
		if battle.power_left>0: g.home_menu.label(g,("SIMBIONTE" if battle.power_kind==7 else "ESCUDO %d" % battle.shield_charges)+" • %d s" % ceili(battle.power_left),Vector2(view.position.x+30,button_y+35),20,g.MINT,false,430)
	if phase=="boost": g.home_menu.label(g,"A HORDA PEGA IMPULSO!",Vector2(view.get_center().x,top+109),23,g.GOLD,true,650)
	if g.lab_active and g.lab_kind=="space":
		var labels = ["RECOMEÇAR","TEMPO: %d s" % int(duration),"SUBIR CAMADA","TESTAR PODER","POUSAR"]
		var actions = ["lab_space_restart","lab_space_time","lab_space_zone","lab_space_power","lab_space_land"]
		var width = (view.size.x-90)/5
		for i in range(5): g.button(Rect2(view.position.x+25+i*(width+10),view.end.y-102,width,43),labels[i],actions[i],Color("513c67"),-2,17)
