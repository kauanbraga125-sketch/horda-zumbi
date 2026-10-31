extends RefCounted
## A temporary chapter of the SAME run. Boats contain stable member IDs.
const WATER = 555.0
const ENTRY_SECONDS = 5.8
const EXIT_SECONDS = 6.4
const SHAFT_DEPTH = 680.0
const ENTRY_GRAVITY = 620.0
const RAMP_WIDTH = 500.0
const RAMP_LIFT = 150.0
const CAPTURE_SECONDS = 1.05
const SEATS = 2
const LEAD = 790.0
const DOCK_TO_EDGE = 232.0
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
var life = preload("res://scripts/sewer_life.gd").new()
var braking = 0.0
var jump_hold_until = -1.0
var camera_left = 0.0
var encounter = preload("res://scripts/sewer_event.gd").new()
var duck_buffer = 0.0
var clean_streak = 0
var sequence: Array = []
var rush_left = 0.0
var layout_columns = 3
var entry_edge_world = 0.0
var entry_travel = 0.0

func reset(seed_value: int) -> void:
	active = false;phase = "ground";age = 0;phase_age = 0;ride_age = 0;completed = 0;captured = 0;hits = 0
	boats.clear();objects.clear();starts.clear();splashes.clear();casualties.clear();history.clear();random.seed = seed_value^0x536e2
	life.reset();braking = 0;jump_hold_until = -1;entry_travel = 0
	encounter.reset(seed_value);duck_buffer = 0;clean_streak = 0;sequence.clear();rush_left = 0;layout_columns = 3

func begin(r,force: bool = false) -> bool:
	if active or r.space.active or r.dead or r.active_count()<=0: return false
	if not force and not r.power_eligible(): return false
	for e in r.entities:
		if e.state=="capture" and e.kind in ["civilian","police","soldier"]: r.complete_capture(e)
	for i in range(r.members.size()-1,-1,-1):
		if r.members[i].falling: r.remove_member(i,"fall")
	if r.dead: return false
	entry_edge_world = encounter.dock_world-DOCK_TO_EDGE if encounter.pending else r.world_px+LEAD-DOCK_TO_EDGE
	active = true;phase = "entry";age = 0;phase_age = 0;ride_age = 0;duration = 32.0;left = duration
	pressure = .23;serial = 0;scroll = 0;next_encounter = .8;jump_buffer = 0;wave_cooldown = 0;clean_exit = true;safe_jumps = 0
	duck_buffer = 0;clean_streak = 0;rush_left = 0;encounter.pending = false
	sequence.assign(["rubble","pipe","fugitive","barrel","gate","rotor","collapse","rescue","rubble","gate","fugitive","barrel"])
	if random.randf()<.5: sequence[3] = "collapse";sequence[6] = "barrel"
	captured = 0;hits = 0;start_world = r.world_px;start_tunnel = r.tunnel_number();entry_travel = 0
	boats.clear();objects.clear();starts.clear();splashes.clear();casualties.clear();history.clear();lane_count = 1;layout_columns = 3
	life.reset();braking = 0;jump_hold_until = -1
	r.perk_left = 0;r.perk_kind = -1;r.transform_left = 0;r.boost_left = 0;r.blessings.reset()
	r.jump_buffer_until = -1;r.wave_holds.clear();r.wave_durations.clear();r.wave_started.clear()
	for m in r.members:
		starts[int(m.id)] = Vector2(m.x,m.y);m.sewer_pose = "run";m.sewer_board = 0.0;m.jump_queue.clear();m.jump_at = -1;m.jump_delay = -1;m.falling = false;m.vy = 0;m.roof_id = -1
		m.sewer_drop_at = -1.0;m.sewer_onboard = false
	assign_boats(r)
	r.mission_stats.sewer_trips = int(r.mission_stats.get("sewer_trips",0))+1
	r.events.append({"type":"sewer_begin"})
	return true

func water_y(x: float) -> float:
	var influence = exp(-pow((x-wave_edge())/180.0,2)) if phase=="ride" else 0.0
	return WATER+sin(x*.013+age*2.4)*7+sin(x*.027-age*3.3)*3+sin(x*.044-age*9)*5*influence

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
		var seat: Dictionary = {}
		for candidate in boats:
			if candidate.ids.size()<SEATS: seat = candidate;break
		if seat.is_empty():
			var slot = 0
			while boats.any(func(b):return int(b.slot)==slot): slot += 1
			seat = {"id":id,"slot":slot,"ids":[],"x":400.0,"y":WATER-24,"vy":0.0,"previous_y":WATER-24,"jump_at":-1.0,"held":0.0,"bump":0.0,"angle":0.0,"arrival":age,"duck_at":-1.0,"duck_left":0.0}
			boats.append(seat);lane_count = maxi(lane_count,slot_lane(slot)+1);layout_columns = maxi(layout_columns,slot_column(slot)+1)
			seat.x = boat_x(r,boats.size()-1)
		seat.ids.append(id)
	boats.sort_custom(func(a,b):return slot_column(int(a.slot))*3+slot_lane(int(a.slot))<slot_column(int(b.slot))*3+slot_lane(int(b.slot)))

func lanes() -> int: return lane_count

func slot_column(slot: int) -> int: return slot%3 if slot<9 else 3+int((slot-9)/3)
func slot_lane(slot: int) -> int: return int(slot/3) if slot<9 else (slot-9)%3

func boat_x(r,index: int) -> float:
	var b = boats[index];var space = minf(215,430.0/maxi(1,layout_columns-1))
	return maxf(r.view_left+330,minf(LEAD,r.view_right-250)-slot_column(int(b.slot))*space-slot_lane(int(b.slot))*42)

func request_jump(r) -> void:
	if not active or phase!="ride": return
	if boats.is_empty() or boats[0].jump_at>=0 or boats[0].y<water_y(boats[0].x)-29+float(boats[0].get("depth",0)): return
	jump_buffer = .15
	jump_hold_until = age
	for i in range(boats.size()):
		var b = boats[i]
		if b.duck_left>.15: b.duck_left = .15
		if b.jump_at<0 and b.y>=water_y(b.x)-29+float(b.get("depth",0)):
			var travel = maxf(0,float(boats[0].x)-float(b.x))/scroll_speed(r)
			var delay = minf(.18,maxi(0,r.active_count()-16)*.003)*float(i)/maxi(1,boats.size()-1)
			b.jump_at = age+travel+delay
			b.hold_for = .08

func request_duck(r) -> void:
	if not active or phase!="ride": return
	duck_buffer = .15
	for b in boats:
		var travel = maxf(0,float(boats[0].x)-float(b.x))/scroll_speed(r)
		b.duck_at = age+travel;b.jump_at = -1
	r.events.append({"type":"sewer_duck"})

func entry_launch() -> float: return smoothstep(3.65,ENTRY_SECONDS,phase_age)
func entry_drop() -> float: return SHAFT_DEPTH*smoothstep(.55,4.15,phase_age)
func entry_depth() -> float: return SHAFT_DEPTH-entry_drop()
func dock_x(r,slot: int) -> float:
	var index = boats.find_custom(func(b):return int(b.slot)==slot)
	return boat_x(r,index) if index>=0 else LEAD
func dock_y(_r,_slot: int) -> float: return WATER-24
func shore_edge() -> float: return entry_edge_world-start_world-entry_travel if active and phase=="entry" else LEAD-DOCK_TO_EDGE
func entry_blend() -> float: return smoothstep(3.15,ENTRY_SECONDS,phase_age)
func exit_blend() -> float: return 1.0 if phase_age>=3.5 else 0.0
func ramp_left(r) -> float: return LEAD+160-scroll_speed(r)*phase_age
func takeoff_at(r,b: Dictionary) -> float: return (LEAD+160+RAMP_WIDTH-float(b.get("exit_x",b.x)))/scroll_speed(r)
func exit_rise(r) -> float:
	var last = 1.2
	for b in boats: last = maxf(last,takeoff_at(r,b))
	return 900*smoothstep(last+.08,last+1.22,phase_age)
func exit_boat(r,b: Dictionary) -> Dictionary:
	var x = float(b.get("exit_x",b.x));var local = clampf((x-ramp_left(r))/RAMP_WIDTH,0,1)
	var launch = phase_age-takeoff_at(r,b)
	var y = float(b.get("exit_y",WATER-24))-RAMP_LIFT*local
	var angle = -.29*sin(local*PI*.5)
	if launch>=0:
		x += launch*150;y = WATER-24-RAMP_LIFT-110*sin(clampf(launch/1.1,0,1)*PI*.5)
		angle = lerpf(-.29,.05,smoothstep(0,1.1,launch))
		if launch>1.1: x += (launch-1.1)*130;y += pow(launch-1.1,2)*290;angle += (launch-1.1)*.65
	return {"p":Vector2(x,y),"angle":angle,"launch":launch}

func reward_line() -> void:
	if not active or phase!="ride": return
	pressure = maxf(.12,pressure-.10);rush_left = 1.6

func add_object(kind: String,x: float,y: float,extra: Dictionary = {}) -> Dictionary:
	var span = {"rubble":100.0,"barrel":36.0,"pipe":112.0,"gate":118.0,"rotor":42.0,"collapse":44.0,"fugitive":90.0}.get(kind,65.0)
	var e = {"kind":kind,"x":x,"previous_x":x,"y":y,"taken":false,"state":"normal","age":0.0,"contacts":{},"row":-1,"width":span,"damaged":false,"passed":false}
	e.merge(extra,true);objects.append(e);return e

func spawn(r,kind: String = "") -> void:
	serial += 1
	var type = kind if not kind.is_empty() else sequence[posmod(serial-1,maxi(1,sequence.size()))]
	var speed = scroll_speed(r);var x = maxf(r.view_right+90,boats[0].x+speed*1.85)
	var e = add_object(type,x,WATER-35,{"encounter":serial,"variant":serial%3})
	if type in ["pipe","gate"]: e.y = WATER-90;e.ceiling_attached = true
	if type=="collapse": e.y = WATER+80;e.warning = .85;e.landed = false
	if type=="rescue": e.y = WATER-8;e.variant = serial%3
	if type=="fugitive": e.y = WATER-24;e.variant = 2 if random.randf()<.60 else random.randi_range(0,1)
	var row = r.new_coin_row(5)
	for i in range(5):
		var height = (120+sin(i*PI/4)*35) if type in ["rubble","barrel","rotor","collapse"] else 58.0
		add_object("coin",x-152+i*76,WATER-height,{"coin_row":row})
	history.append({"kind":type,"time":ride_age,"members":r.active_count()})
	next_encounter = 2.65 if type not in ["rescue","fugitive"] else 2.9
	var titles = {"pipe":"CANO BAIXO • ABAIXE!","gate":"COMPORTA FECHANDO • ABAIXE!","rescue":"SOBREVIVENTE À FRENTE • RESGATE","fugitive":"JET-SKI FUGINDO • ALCANCE OS SOBREVIVENTES!","rubble":"NAUFRÁGIO • SALTE!","barrel":"BARRIL EXPLOSIVO • SALTE!","rotor":"BOMBA GIRATÓRIA • SEGURE O SALTO!","collapse":"ESPINHO NA ÁGUA • SALTE!"}
	r.events.append({"type":"sewer_encounter","title":titles[type],"kind":type})

func scroll_speed(r) -> float: return clampf((r.view_right-r.view_left)*.49,565,705)*(1-braking*.15)*(1.055 if rush_left>0 else 1.0)

func tail_x() -> float:
	var tail = LEAD
	for b in boats: tail = minf(tail,float(b.x)-130)
	return tail

func wave_edge() -> float: return maxf(camera_left+190,tail_x()-lerpf(50,-25,pressure))

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
	if phase=="entry": entry_travel = r.world_px-start_world
	camera_left = r.view_left
	braking = maxf(0,braking-dt*.85);rush_left = maxf(0,rush_left-dt)
	if held and jump_hold_until>=0:
		var duration_held = clampf(age-jump_hold_until,.08,.19)
		for b in boats:
			if b.jump_at>=0 or b.vy<0: b.hold_for = duration_held
	if phase=="entry": scroll += scroll_speed(r)*dt*.65*entry_launch()
	life.advance(self,r,dt)
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
		next_encounter -= dt;pressure = move_toward(pressure,.28+ride_age/duration*.16,dt*.018);wave_cooldown = maxf(0,wave_cooldown-dt)
		if next_encounter<=0 and left>3.6: spawn(r)
	for i in range(boats.size()):
		var b = boats[i]
		b.depth = lerpf(float(b.get("depth",0)),float(slot_lane(int(b.slot)))*40,1-exp(-dt*5))
		var floor_y = water_y(b.x)-24+float(b.depth)
		b.x = lerpf(float(b.x),boat_x(r,i)+float(b.bump),1-exp(-dt*8));b.bump = move_toward(b.bump,0,dt*38);b.previous_y = b.y
		b.duck_left = maxf(0,b.duck_left-dt)
		if b.duck_at>=0 and age>=b.duck_at: b.duck_at = -1;b.duck_left = 1.25
		if phase=="entry":
			b.x = boat_x(r,i);b.y = floor_y+entry_depth()
			b.vy = 0;b.angle = sin(age*4+i)*.012
			continue
		if b.jump_at>=0 and age>=b.jump_at:
			b.jump_at = -1;b.vy = -860;b.held = 0;splash(Vector2(b.x-38,b.y+27),false)
		if b.y<floor_y-1 or b.vy<0:
			b.held += dt
			b.vy += (1250 if b.vy<0 and b.held<=float(b.get("hold_for",.08))+dt*.6 else 1650)*dt
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
			for b in boats: b.exit_x = b.x;b.exit_y = b.y
			for m in r.members: starts[int(m.id)] = Vector2(m.x,m.y)
			r.events.append({"type":"sewer_exit"})
	_update_members(r,dt)

func _update_members(r,_dt: float) -> void:
	for b in boats:
		for seat in range(b.ids.size()):
			var index = r.members.find_custom(func(m):return int(m.id)==int(b.ids[seat]))
			if index<0: continue
			var m = r.members[index]
			var local = Vector2(18-seat*80,21);var foot = Vector2(b.x,b.y)+local.rotated(float(b.angle))
			m.sewer_pose = "duck" if b.duck_left>.12 else "ride"
			if phase=="entry":
				var start = Vector2(starts.get(int(m.id),foot))
				if float(m.get("sewer_drop_at",-1))<0 and shore_edge()<=start.x:
					# The moving road edge is shared with the renderer; each foot crosses once.
					var passed = maxf(0,start.x-shore_edge())/maxf(1,r.speed)
					m.sewer_drop_at = maxf(0,phase_age-minf(_dt,passed))
				if float(m.get("sewer_drop_at",-1))<0:
					foot = Vector2(start.x,lerpf(start.y,r.FLOOR,smoothstep(0,.4,phase_age))-entry_drop())
					m.sewer_pose = "run" if start.y>=r.FLOOR-6 or phase_age>=.4 else "board"
				else:
					var target = Vector2(b.x,b.y+entry_drop())+local.rotated(float(b.angle))
					var duration_fall = sqrt(2*maxf(1,target.y-r.FLOOR)/ENTRY_GRAVITY)
					var falling_time = maxf(0,phase_age-float(m.sewer_drop_at))
					var u = clampf(falling_time/duration_fall,0,1)
					var travel = u+u*u-u*u*u
					foot = Vector2(lerpf(start.x,target.x,travel),r.FLOOR+.5*ENTRY_GRAVITY*falling_time*falling_time-entry_drop())
					m.sewer_pose = "board";m.sewer_board = u
					if u>=1:
						foot = target-Vector2(0,entry_drop());m.sewer_pose = "ride"
						if not bool(m.get("sewer_onboard",false)):
							m.sewer_onboard = true;splash(Vector2(b.x,b.y+28),false)
			elif phase=="exit":
				var flight = exit_boat(r,b);var launch = float(flight.launch)
				foot = Vector2(flight.p)+local.rotated(float(flight.angle));m.sewer_angle = flight.angle
				if launch>1.1:
					var detach = Vector2(float(b.get("exit_x",b.x))+165,WATER-24-RAMP_LIFT-110)+local.rotated(.05)
					var air = launch-1.1;var t = clampf((air-.35)/1.55,0,1)
					foot = detach.lerp(Vector2(r.slot_x(index),r.FLOOR),smoothstep(0,1,t))+Vector2(0,-sin(clampf(air/.35,0,1)*PI)*13)
					m.sewer_pose = "land" if t>=1 else "return"
				else: m.sewer_pose = "ride"

			m.x = foot.x;m.y = foot.y;m.vy = b.vy;m.falling = false;m.roof_id = -1;m.air_time += _dt;m.air_pose = 0;m.jump_queue.clear();m.run_phase += _dt*.75
			if phase!="exit": m.sewer_angle = b.angle
			m.hurt_left = maxf(0,float(m.hurt_left)-_dt)

func _update_objects(r,dt: float) -> void:
	var step = scroll_speed(r)*dt
	for e in objects:
		e.previous_x = e.x;e.x -= step*(.74 if e.kind=="fugitive" else 1.0);e.age += dt
		if e.kind=="collapse" and not e.taken:
			var drop = maxf(0,float(e.age)-float(e.get("warning",1.0)))
			e.y = lerpf(WATER+80,WATER-50,smoothstep(0,.28,drop))
			if drop>=.28 and not bool(e.get("landed",false)):
				e.landed = true;splash(Vector2(e.x,WATER-20),false);r.events.append({"type":"sewer_collapse","x":e.x,"y":e.y})
		if e.taken: continue
		if e.state=="capture":
			if e.age>=CAPTURE_SECONDS:
				complete_rescue(r,e)
			continue
		for b in boats:
			if e.taken or r.dead: break
			var hazard = e.kind in ["rubble","barrel","pipe","gate","rotor","collapse"]
			var cross = minf(e.previous_x,e.x)-e.width<=b.x+(112 if hazard else 0) and maxf(e.previous_x,e.x)+e.width>=b.x-(115 if hazard else 0)
			if not cross: continue
			if e.kind=="coin":
				if absf(float(b.y)-42-float(e.y))<67:
					e.taken = true;r.coins += 1;r.collect_coin_row(e);r.events.append({"type":"coin","amount":1,"x":e.x,"y":e.y,"physical_pickup":true})
			elif e.kind in ["rescue","fugitive"]:
				if absf(float(b.y)-float(e.y))<115:
					e.state = "capture";e.age = 0;e.capture_boat_id = b.id;e.capture_origin = Vector2(e.x,e.y);splash(Vector2(e.x,WATER),false)
			elif not e.contacts.has(b.id):
				var depth = float(b.get("depth",0))
				var lift = water_y(b.x)-24+depth-float(b.y)
				var clearance = 77.0
				if e.kind=="rotor": clearance = 123-minf(30,maxf(0,absf(float(e.x)-float(b.x))-50)*.3)
				var collide = (b.duck_left<=.10 or lift>22) if e.kind in ["pipe","gate"] else lift<clearance
				if e.kind=="collapse" and not bool(e.get("landed",false)): collide = false
				if collide:
					e.contacts[b.id] = true
					e.damaged = true;b.bump = -23;b.vy = maxf(b.vy,190)
					if e.kind in ["pipe","gate"]: b.y = maxf(b.y,WATER-29+depth);b.duck_left = .55
					if int(e.get("damage_count",0))<2:
						e.damage_count = int(e.get("damage_count",0))+1;damage_boat(r,b,"sewer_"+str(e.kind))
					if e.kind not in ["pipe","gate","collapse","rotor"]:
						e.taken = true;splash(Vector2(e.x,WATER-25),e.kind=="barrel")
						if e.kind=="barrel": r.events.append({"type":"sewer_blast","x":e.x,"y":WATER-35})
		if not e.passed and e.kind in ["rubble","barrel","pipe","gate","rotor","collapse"] and not boats.is_empty() and e.x<tail_x()-70:
			e.passed = true
			if not e.damaged: safe_jumps += 1;r.clean_jumps += 1;clean_streak += 1;pressure = maxf(.12,pressure-.045)
	for i in range(objects.size()-1,-1,-1):
		if (objects[i].state!="capture" and objects[i].x<r.view_left-180) or (objects[i].taken and objects[i].age>1):
			if objects[i].kind=="coin" and not objects[i].taken: r.miss_coin_row(objects[i])
			objects.remove_at(i)

func damage_boat(r,b: Dictionary,cause: String) -> void:
	if r.hit_grace>0: return
	for id in b.ids.duplicate():
		var index = r.members.find_custom(func(m):return int(m.id)==int(id))
		if index<0: continue
		var before = r.losses;r.damage(index,cause)
		r.hit_grace = maxf(r.hit_grace,.8);pressure = minf(1,pressure+.21);b.bump = -25;braking = 1;clean_streak = 0
		if r.losses>before: hits += 1;clean_exit = false
		splash(Vector2(b.x,b.y),false);r.events.append({"type":"sewer_hit","x":b.x,"y":b.y,"cause":cause});break

func complete_rescue(r,e: Dictionary) -> void:
	if e.taken: return
	e.taken = true
	var count = 2 if e.kind=="fugitive" and int(e.variant)==2 else 1
	for i in range(count):
		r.souls += 1;captured += 1
		var kind = r.recruit_kind();r.add_member(kind,true)
		r.mission_stats.civilians = int(r.mission_stats.get("civilians",0))+1
		r.events.append({"type":"soul","kind":kind,"x":e.x+i*28,"y":e.y,"soldier":false,"from_vehicle":e.kind=="fugitive"})
	assign_boats(r)
	if e.kind=="fugitive": r.events.append({"type":"sewer_fugitives","count":count})

func splash(point: Vector2,explosion: bool) -> void:
	if splashes.size()>16: splashes.pop_front()
	splashes.append({"p":point,"age":0.0,"explosion":explosion})

func casualty(r,m: Dictionary,kind: int) -> void:
	if casualties.size()>=10: casualties.pop_front()
	casualties.append({"p":Vector2(m.x,m.y),"kind":kind,"wear":r.cosmetics_for(m,kind).duplicate(),"age":0.0})

func prepare_landing(r) -> void:
	r.entities.clear();r.physics_surfaces.clear();r.physics_gaps.clear()
	reserve_ground(r,r.world_px+r.generation_horizon()+3500)

func reserve_ground(r,end: float) -> void:
	r.physics_surfaces.clear();r.physics_gaps.clear()
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
	encounter.complete(r)
	r.mission_stats.sewer_captures = int(r.mission_stats.get("sewer_captures",0))+captured
	r.events.append({"type":"sewer_land","metres":int((r.world_px-start_world)/30),"to_tunnel":r.tunnel_number(),"clean":clean_exit})
