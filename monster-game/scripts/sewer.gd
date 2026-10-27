extends RefCounted
## A temporary chapter of the SAME run. Boats contain stable member IDs.
const POWER = 9
const WATER = 555.0
const ENTRY_SECONDS = 2.2
const EXIT_SECONDS = 3.0
var active = false
var phase = "ground"
var age = 0.0
var phase_age = 0.0
var ride_age = 0.0
var duration = 30.0
var left = 30.0
var pressure = .12
var scroll = 0.0
var serial = 0
var next_encounter = 1.0
var start_world = 0.0
var start_tunnel = 0
var completed = 0
var captured = 0
var hits = 0
var safe_jumps = 0
var clean_exit = true
var wave_cooldown = 0.0
var objects: Array[Dictionary] = []
var boats: Array[Dictionary] = []
var starts: Dictionary = {}
var casualties: Array[Dictionary] = []
var splashes: Array[Dictionary] = []
var history: Array[Dictionary] = []
var visual = preload("res://scripts/sewer_visual.gd").new()
var jump_buffer = 0.0
var lane_count = 1
var random = RandomNumberGenerator.new()

func reset(seed_value: int) -> void:
	active = false;phase = "ground";age = 0;phase_age = 0;ride_age = 0;completed = 0;captured = 0;hits = 0
	boats.clear();objects.clear();starts.clear();splashes.clear();casualties.clear();history.clear();random.seed = seed_value^0x536e2

func begin(r,force: bool = false) -> bool:
	if active or r.space.active or r.dead or r.active_count()<=0: return false
	if not force and (POWER not in r.power_owned or not r.power_eligible()): return false
	for e in r.entities:
		if e.state=="capture" and e.kind in ["civilian","police","soldier"]: r.complete_capture(e)
	for i in range(r.members.size()-1,-1,-1):
		if r.members[i].falling: r.remove_member(i,"fall")
	if r.dead: return false
	active = true;phase = "entry";age = 0;phase_age = 0;ride_age = 0;duration = 30+int(r.power_levels.get("sewer_time",0))*4;left = duration
	pressure = .12;serial = 0;scroll = 0;next_encounter = 1.0;jump_buffer = 0;wave_cooldown = 0;clean_exit = true;safe_jumps = 0
	captured = 0;hits = 0;start_world = r.world_px;start_tunnel = r.tunnel_number()
	boats.clear();objects.clear();starts.clear();splashes.clear();casualties.clear();history.clear();lane_count = 1
	r.perk_left = 0;r.perk_kind = -1;r.transform_left = 0;r.boost_left = 0;r.blessings.reset()
	r.jump_buffer_until = -1;r.wave_holds.clear();r.wave_durations.clear();r.wave_started.clear()
	for m in r.members:
		starts[int(m.id)] = Vector2(m.x,m.y);m.jump_queue.clear();m.jump_at = -1;m.jump_delay = -1;m.falling = false;m.vy = 0;m.roof_id = -1
	assign_boats(r);r.mark_power_collected();r.bonuses += 1
	r.mission_stats.sewer_trips = int(r.mission_stats.get("sewer_trips",0))+1
	r.events.append({"type":"sewer_begin"})
	return true

func water_y(x: float) -> float: return WATER+sin(x*.013+age*2.4)*7+sin(x*.027-age*3.3)*3

func assign_boats(r) -> void:
	var living: Array = []
	for m in r.members: living.append(int(m.id))
	for b in boats:
		b.ids = b.ids.filter(func(id):return id in living)
	boats = boats.filter(func(b):return not b.ids.is_empty())
	var assigned: Array = []
	for b in boats: assigned.append_array(b.ids)
	for id in living:
		if id in assigned: continue
		if boats.is_empty() or boats[-1].ids.size()>=3:
			boats.append({"id":id,"ids":[],"x":400.0,"y":WATER-24,"vy":0.0,"previous_y":WATER-24,"jump_at":-1.0,"held":0.0,"bump":0.0,"angle":0.0,"arrival":age})
			lane_count = maxi(lane_count,1 if boats.size()<=3 else 2 if boats.size()<=12 else 3)
			boats[-1].x = boat_x(r,boats.size()-1)
		boats[-1].ids.append(id)

func lanes() -> int: return lane_count

func boat_x(r,index: int) -> float:
	var rows = lanes();var columns = ceili(float(boats.size())/rows)
	var space = minf(158,440.0/maxi(1,columns-1))
	return maxf(r.view_left+72,460-int(index/rows)*space-(index%rows)*23)

func request_jump(r) -> void:
	if not active or phase!="ride": return
	jump_buffer = .15
	for i in range(boats.size()):
		var b = boats[i]
		if b.jump_at<0 and b.y>=water_y(b.x)-29:
			var travel = maxf(0,float(boats[0].x)-float(b.x))/scroll_speed(r)
			var delay = minf(.18,maxi(0,r.active_count()-16)*.003)*float(i)/maxi(1,boats.size()-1)
			b.jump_at = age+travel+delay

func add_object(kind: String,x: float,y: float,extra: Dictionary = {}) -> Dictionary:
	var e = {"kind":kind,"x":x,"previous_x":x,"y":y,"taken":false,"state":"normal","age":0.0,"contacts":{},"row":-1,"width":65.0,"damaged":false,"passed":false}
	e.merge(extra,true);objects.append(e);return e

func spawn(r,kind: String = "") -> void:
	serial += 1
	var type = kind if not kind.is_empty() else ["rubble","pipe","barrel","rescue","rubble","barrel","rescue"][posmod(serial-1,7)]
	var speed = scroll_speed(r);var x = maxf(r.view_right+70,460+speed*2.8)
	var e = add_object(type,x,WATER-35,{"width":80.0 if type=="pipe" else 65.0,"encounter":serial})
	if type=="pipe": e.y = WATER-155
	if type=="rescue": e.y = WATER-40
	var row = r.new_coin_row(5)
	for i in range(5):
		var height = (105+sin(i*PI/4)*35) if type in ["rubble","barrel"] else 54.0
		add_object("coin",x-125+i*54,WATER-height,{"coin_row":row})
	history.append({"kind":type,"time":ride_age,"members":r.active_count()})
	next_encounter = 4.7 if type!="rescue" else 4.1
	r.events.append({"type":"sewer_encounter","title":"CANO BAIXO • PASSE POR BAIXO" if type=="pipe" else "ALGUÉM NA ÁGUA • RESGATE" if type=="rescue" else "SALTE SOBRE OS DESTROÇOS" if type=="rubble" else "BARRIL EXPLOSIVO • SALTE"})

func scroll_speed(r) -> float: return clampf((r.view_right-r.view_left)*.30,330,440)

func _world(r,dt: float) -> void:
	var target = HordeDirector.stage_speed(r.tunnel_number())*1.10
	r.cruise_speed = move_toward(r.cruise_speed,target,dt*90);r.speed = r.cruise_speed;r.last_effective_speed = r.speed;r.time_scale = 1
	r.world_px += r.speed*dt;r.update_tunnels();r.hit_grace = maxf(0,r.hit_grace-dt)
	for e in r.entities: e.x -= r.speed*dt
	if r.tunnel_number()!=r.last_tunnel:
		r.last_tunnel = r.tunnel_number();r.events.append({"type":"tunnel","area":r.area(),"number":r.last_tunnel})

func advance(r,dt: float,held: bool) -> void:
	if not active or r.dead: return
	age += dt;phase_age += dt;_world(r,dt);assign_boats(r)
	for list in [splashes,casualties]:
		for i in range(list.size()-1,-1,-1):
			list[i].age += dt
			if list[i].age>1: list.remove_at(i)
	if phase=="exit":
		_update_members(r,dt)
		if phase_age>=EXIT_SECONDS: finish(r)
		return
	if phase=="ride":
		ride_age += dt;left = maxf(0,left-dt);scroll += scroll_speed(r)*dt
		next_encounter -= dt;pressure = maxf(.09,pressure-dt*.017);wave_cooldown = maxf(0,wave_cooldown-dt)
		if next_encounter<=0 and left>3.6: spawn(r)
	for i in range(boats.size()):
		var b = boats[i];var floor_y = water_y(b.x)-24+(i%lanes())*12
		b.x = lerpf(float(b.x),boat_x(r,i)+float(b.bump),1-exp(-dt*8));b.bump = move_toward(b.bump,0,dt*38);b.previous_y = b.y
		if b.jump_at>=0 and age>=b.jump_at:
			b.jump_at = -1;b.vy = -690;b.held = 0;splash(Vector2(b.x-38,b.y+27),false)
		if b.y<floor_y-1 or b.vy<0:
			b.held += dt
			b.vy += (1250 if held and b.vy<0 and b.held<.19 else 1850)*dt
			b.y += b.vy*dt
			if b.y>=floor_y:
				b.y = floor_y;b.vy = 0;splash(Vector2(b.x,b.y+28),false)
		else: b.y = floor_y;b.vy = 0
		b.angle = clampf(b.vy*.00023,-.18,.17)+sin(age*3+i)*.015
	if phase=="entry" and phase_age>=ENTRY_SECONDS: phase = "ride";phase_age = 0;r.hit_grace = .8
	if phase=="ride":
		_update_objects(r,dt)
		if pressure>=.94 and wave_cooldown<=0 and not boats.is_empty():
			var b = boats[-1];damage_boat(r,b,"sewer_wave");wave_cooldown = 2.2;pressure = .69
		if left<=0 and not r.dead:
			for e in objects:
				if not e.taken and e.state=="capture": complete_rescue(r,e)
			objects.clear()
			prepare_landing(r);phase = "exit";phase_age = 0
			for m in r.members: starts[int(m.id)] = Vector2(m.x,m.y)
			r.events.append({"type":"sewer_exit"})
	_update_members(r,dt)

func _update_members(r,_dt: float) -> void:
	for b in boats:
		for seat in range(b.ids.size()):
			var index = r.members.find_custom(func(m):return int(m.id)==int(b.ids[seat]))
			if index<0: continue
			var m = r.members[index]
			var local = Vector2(-4-seat*37,14);var foot = Vector2(b.x,b.y)+local.rotated(float(b.angle))
			if phase=="entry": foot = Vector2(starts.get(int(m.id),foot)).lerp(foot,smoothstep(.15,ENTRY_SECONDS,phase_age))
			elif phase=="exit":
				var t = clampf(phase_age/EXIT_SECONDS,0,1);var start = Vector2(starts.get(int(m.id),foot))
				foot = start.lerp(Vector2(r.slot_x(index),r.FLOOR),smoothstep(0,1,t))+Vector2(sin(t*PI)*150,-sin(t*PI)*215)
			m.x = foot.x;m.y = foot.y;m.vy = b.vy;m.falling = false;m.roof_id = -1;m.air_time += _dt;m.air_pose = 0;m.jump_queue.clear();m.run_phase += _dt*.75
			m.sewer_angle = b.angle;m.hurt_left = maxf(0,float(m.hurt_left)-_dt)

func _update_objects(r,dt: float) -> void:
	var step = scroll_speed(r)*dt
	for e in objects:
		e.previous_x = e.x;e.x -= step;e.age += dt
		if e.taken: continue
		if e.state=="capture":
			if e.age>=.55:
				complete_rescue(r,e)
			continue
		for b in boats:
			if e.taken or r.dead: break
			var cross = minf(e.previous_x,e.x)-e.width<=b.x and maxf(e.previous_x,e.x)+e.width>=b.x
			if not cross: continue
			if e.kind=="coin":
				if absf(float(b.y)-42-float(e.y))<67:
					e.taken = true;r.coins += 1;r.collect_coin_row(e);r.events.append({"type":"coin","amount":1,"x":e.x,"y":e.y,"physical_pickup":true})
			elif e.kind=="rescue":
				if absf(float(b.y)-float(e.y))<115: e.state = "capture";e.age = 0;splash(Vector2(e.x,WATER),false)
			elif not e.contacts.has(b.id):
				var lift = WATER-24-float(b.y)
				var collide = lift>51 if e.kind=="pipe" else lift<77
				e.contacts[b.id] = true
				if collide:
					e.damaged = true;b.bump = -23;b.vy = maxf(b.vy,190)
					if e.kind=="pipe": b.y = maxf(b.y,WATER-69)
					if int(e.get("damage_count",0))<2:
						e.damage_count = int(e.get("damage_count",0))+1;damage_boat(r,b,"sewer_"+str(e.kind))
					if e.kind!="pipe": e.taken = true;splash(Vector2(e.x,WATER-25),true)
		if not e.passed and e.kind in ["rubble","barrel","pipe"] and not boats.is_empty() and e.x<boats[-1].x-100:
			e.passed = true
			if not e.damaged: safe_jumps += 1;r.clean_jumps += 1;pressure = maxf(.09,pressure-.05)
	for i in range(objects.size()-1,-1,-1):
		if objects[i].x<r.view_left-180 or (objects[i].taken and objects[i].age>1):
			if objects[i].kind=="coin" and not objects[i].taken: r.miss_coin_row(objects[i])
			objects.remove_at(i)

func damage_boat(r,b: Dictionary,cause: String) -> void:
	if r.hit_grace>0: return
	for id in b.ids.duplicate():
		var index = r.members.find_custom(func(m):return int(m.id)==int(id))
		if index<0: continue
		var before = r.losses;r.damage(index,cause)
		r.hit_grace = maxf(r.hit_grace,.8);pressure = minf(1,pressure+.18);b.bump = -25
		if r.losses>before: hits += 1;clean_exit = false
		splash(Vector2(b.x,b.y),false);r.events.append({"type":"sewer_hit","x":b.x,"y":b.y});break

func complete_rescue(r,e: Dictionary) -> void:
	if e.taken: return
	e.taken = true;r.souls += 1;captured += 1
	var kind = r.recruit_kind();r.add_member(kind,true);assign_boats(r)
	r.mission_stats.civilians = int(r.mission_stats.get("civilians",0))+1
	r.events.append({"type":"soul","kind":kind,"x":e.x,"y":e.y,"soldier":false,"from_vehicle":false})

func splash(point: Vector2,explosion: bool) -> void:
	if splashes.size()>16: splashes.pop_front()
	splashes.append({"p":point,"age":0.0,"explosion":explosion})

func casualty(r,m: Dictionary,kind: int) -> void:
	if casualties.size()>=10: casualties.pop_front()
	casualties.append({"p":Vector2(m.x,m.y),"kind":kind,"wear":r.cosmetics_for(m,kind).duplicate(),"age":0.0})

func prepare_landing(r) -> void:
	r.entities.clear();r.physics_surfaces.clear();r.physics_gaps.clear()
	var end = r.world_px+r.generation_horizon()+3500
	r.terrain.segments.assign([{"start":r.world_px-100000.0,"end":end,"height":0.0,"state":HordeTerrain.State.NORMAL}])
	r.terrain.generated_to = end;r.terrain.state = HordeTerrain.State.NORMAL
	r.next_pattern_world = r.world_px+maxf(r.view_right,r.planning_right)+r.speed*1.5+300

func finish(r) -> void:
	prepare_landing(r);active = false;phase = "ground";completed += 1
	r.recovery_left = 2.5;r.recovery_speed = HordeDirector.stage_speed(r.tunnel_number());r.hit_grace = 2.2;r.cached_active = -1
	r.jump_buffer_until = -1;r.wave_holds.clear();r.wave_durations.clear();r.wave_started.clear()
	for i in range(r.members.size()):
		var m = r.members[i];m.x = r.slot_x(i);m.y = r.ground_y(m.x);m.vy = 0;m.falling = false;m.air_time = 0;m.air_pose = 0;m.air_jumps = 0;m.roof_id = -1;m.land_left = .24;m.jump_queue.clear();m.jump_at = -1;m.jump_delay = -1
	objects.clear();r.bonus_director.collected(r)
	r.mission_stats.sewer_captures = int(r.mission_stats.get("sewer_captures",0))+captured
	r.events.append({"type":"sewer_land","metres":int((r.world_px-start_world)/30),"to_tunnel":r.tunnel_number(),"clean":clean_exit})
