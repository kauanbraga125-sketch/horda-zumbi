extends RefCounted
## Encounter deck, ship boarding, real member losses and exclusive orbital powers.
const SHIPS = {
	"tour_bus":{"frame":0,"hp":2,"need":2,"crew":3,"size":245.0,"label":"EXCURSÃO ORBITAL"},
	"cargo":{"frame":2,"hp":3,"need":5,"crew":2,"size":280.0,"label":"CARGUEIRO INFECTADO"},
	"saucer":{"frame":4,"hp":3,"need":7,"crew":2,"size":245.0,"label":"DISCO DE INVASÃO"},
	"fighter":{"frame":6,"hp":2,"need":4,"crew":1,"size":230.0,"label":"CAÇA DE SUCATA"},
	"ghost_frigate":{"frame":8,"hp":5,"need":12,"crew":4,"size":330.0,"label":"FRAGATA DO HORIZONTE"}
}
var art = preload("res://scripts/adventure_art.gd").new()
var deck: Array[String] = []
var serial = 0
var shot_clock = 0.0
var destroyed = 0
var power_left = 0.0
var power_kind = -1
var shield_charges = 0
var pilot_left = 0.0
var pilot_kind = ""
var pilot_hp = 0
var last_hit = -10.0

func reset() -> void:
	deck.clear();serial = 0;shot_clock = 0;destroyed = 0;power_left = 0;power_kind = -1;shield_charges = 0;pilot_left = 0;pilot_kind = "";pilot_hp = 0;last_hit = -10

func spawn_ship(s, r, kind: String, at_x: float, at_y: float) -> Dictionary:
	var spec: Dictionary = SHIPS[kind]
	return s.add_object(kind,at_x,at_y,{"hp":spec.hp,"max_hp":spec.hp,"need":spec.need,"radius":87.0,"speed":.72,"shot":1.1,"last_dash":-1,"hit_at":-10.0})

func spawn(s,r) -> void:
	if s.objects.size()>65: return
	if deck.is_empty():
		deck.assign(["tour_bus","cargo","fighter","meteor","parasite","saucer","drone","corridor"])
		# Seeded shuffle keeps a finite variety of encounters without repeating one.
		for i in range(deck.size()-1,0,-1):
			var j = s.random.randi_range(0,i);var old = deck[i];deck[i] = deck[j];deck[j] = old
	var kind = deck.pop_front();serial += 1
	var x = r.view_right+150;var lane = s.random.randf_range(280,470)
	if s.zone()>=3 and serial%7==0: kind = "ghost_frigate"
	if SHIPS.has(kind):
		var ships = 0
		for e in s.objects:
			if SHIPS.has(e.kind) and not e.taken: ships += 1
		if ships<4: spawn_ship(s,r,kind,x,lane)
	elif kind=="meteor":
		for i in range(2 if r.active_count()<16 else 3): s.add_object("meteor",x+i*145,255+i*120,{"variant":i%3,"radius":35.0,"speed":.9})
	elif kind=="parasite":
		for i in range(2 if r.active_count()<16 else 4): s.add_object("parasite",x+i*110,lane+(i%2)*70,{"radius":35.0,"speed":.85})
	elif kind=="drone": s.add_object("drone",x,lane,{"radius":35.0,"speed":.65})
	else:
		var laser_y = 300.0 if serial%2==0 else 490.0
		s.add_object("beam",r.view_right-20,laser_y,{"radius":20.0,"speed":0.0,"contacts":{},"hit_at":-10.0})
		if r.active_count()>=20: s.add_object("satellite",x+160,430 if laser_y<400 else 275,{"radius":42.0,"speed":.65})
	var row = r.new_coin_row(5)
	for i in range(5): s.add_object("coin",x+120+i*62,lane+sin(i*.7)*32,{"radius":22.0,"coin_row":row,"speed":1.0})
	if serial%3==1: s.add_object("astronaut",x+280,clampf(lane+75,250,510),{"radius":38.0,"speed":.75})
	if serial%3==0: s.add_object("core",x+270,lane-55,{"radius":29.0,"speed":.8})
	if serial%5==0:
		var choices = ["fuel"]
		if 7 in r.power_owned: choices.append("alien_power")
		if 8 in r.power_owned: choices.append("orbital_power")
		s.add_object(choices[s.random.randi_range(0,choices.size()-1)],x+350,lane,{"radius":31.0,"speed":.8})
	if serial%11==0: s.add_object("eye",x+440,330,{"radius":24.0,"speed":.8})

func give_power(s,r,kind: int) -> void:
	power_kind = kind;shield_charges = 3 if kind==8 else 0
	power_left = (7.0+int(r.power_levels.get("alien_time",0))*2) if kind==7 else (8.0+int(r.power_levels.get("orbital_time",0))*2)
	r.events.append({"type":"space_discovery","title":"SIMBIONTE CÓSMICO!" if kind==7 else "ESCUDO ORBITAL • 3 CARGAS"})

func nearest_member(r,point: Vector2,radius: float) -> int:
	var index = -1;var best = radius
	for i in range(r.members.size()):
		var m = r.members[i]
		if m.falling: continue
		var d = Vector2(m.x,m.y-55).distance_to(point)
		if d<best: best = d;index = i
	return index

func hurt(s,r,index: int,cause: String,point: Vector2) -> bool:
	if index<0 or s.phase not in ["flight"] or s.age-last_hit<.28: return false
	if shield_charges>0 and power_left>0:
		shield_charges -= 1;last_hit = s.age;r.events.append({"type":"spectral_guard","x":point.x,"y":point.y})
		if shield_charges==0: power_left = 0
		return true
	if pilot_left>0 and pilot_hp>0:
		pilot_hp -= 1;last_hit = s.age
		if pilot_hp==0: pilot_left = 0;r.hit_grace = .7
		r.events.append({"type":"space_hit","x":point.x,"y":point.y});return true
	if s.dash_left>0: return false
	if r.damage(index,cause):
		last_hit = s.age;s.hurt_left = .4;s.hits += 1
		r.events.append({"type":"space_hit","x":point.x,"y":point.y});return true
	return false

func capture(s,r,e: Dictionary) -> void:
	if e.taken: return
	e.taken = true;s.captured += 1;r.souls += 1;r.recruits += 1
	r.mission_stats.civilians = int(r.mission_stats.get("civilians",0))+1;r.mission_stats.space_captures = int(r.mission_stats.get("space_captures",0))+1
	var kind = r.recruit_kind();r.add_member(kind,false,Vector2(MonsterCatalog.ANCHOR-35,s.y))
	s.charge = minf(100,s.charge+14)
	r.events.append({"type":"soul","kind":kind,"x":e.x,"y":e.y,"soldier":false,"from_vehicle":false})

func destroy_ship(s,r,e: Dictionary) -> void:
	if e.taken: return
	e.taken = true;destroyed += 1;s.charge = minf(100,s.charge+28)
	r.coins += 8;r.events.append({"type":"coin","amount":8,"x":e.x,"y":e.y})
	r.events.append({"type":"space_smash","x":e.x,"y":e.y,"title":SHIPS[e.kind].label})
	r.mission_stats.space_ships = int(r.mission_stats.get("space_ships",0))+1
	for i in range(int(SHIPS[e.kind].crew)):
		s.add_object("astronaut",e.x-45+i*48,e.y+(i%2)*55,{"radius":39.0,"speed":.55,"seed":i*1.4})
	if e.kind in ["tour_bus","fighter"] and pilot_left<=0:
		pilot_kind = e.kind;pilot_left = 8.0;pilot_hp = 3
		r.events.append({"type":"space_discovery","title":"NAVE TOMADA • PILOTE POR 8 SEGUNDOS!"})
	if e.kind=="cargo": s.add_object("parasite",e.x+100,e.y-45,{"radius":32.0,"speed":.5})
	if e.kind=="saucer": s.add_object("core",e.x+60,e.y+50,{"radius":30.0,"speed":.5})

func hit_ship(s,r,e: Dictionary,force: int = 1) -> void:
	if e.taken: return
	e.hp = int(e.hp)-force;e.flash = .2
	r.events.append({"type":"space_smash","x":e.x,"y":e.y})
	if int(e.hp)<=0: destroy_ship(s,r,e)

func fire(s,r,acid: bool) -> void:
	var target: Dictionary = {};var nearest = INF
	for e in s.objects:
		if not e.taken and SHIPS.has(e.kind) and e.x>MonsterCatalog.ANCHOR and e.x<nearest: target = e;nearest = e.x
	if target.is_empty(): return
	var origin = Vector2(MonsterCatalog.ANCHOR+70,s.y-57)
	var direction = (Vector2(target.x,target.y)-origin).normalized()
	s.add_object("acid" if acid else "friendly_shot",origin.x,origin.y,{"vx":direction.x*680,"vy":direction.y*680,"speed":0.0,"radius":13.0})

func advance(s,r,dt: float) -> void:
	power_left = maxf(0,power_left-dt);pilot_left = maxf(0,pilot_left-dt)
	if power_left<=0: power_kind = -1;shield_charges = 0
	shot_clock -= dt
	if (power_kind==7 or pilot_left>0) and shot_clock<=0:
		fire(s,r,power_kind==7);shot_clock = .65 if power_kind==7 else .5
	for e in s.objects.duplicate():
		if e.taken: continue
		e.age += dt;e.angle += float(e.spin)*dt;e.flash = maxf(0,float(e.get("flash",0))-dt)
		if e.kind in ["shot","acid","friendly_shot"]:
			e.x += float(e.vx)*dt;e.base_y += float(e.vy)*dt;e.y = e.base_y
		else:
			e.x -= r.speed*float(e.speed)*dt
			e.y = float(e.base_y)+sin(float(e.age)*2+float(e.seed))*(3 if e.kind=="coin" else 9)
		if e.state=="capture":
			var lead = r.leader_index()
			if lead<0: return
			e.x = move_toward(e.x,r.members[lead].x+20,dt*240);e.y = move_toward(e.y,s.y-50,dt*140);e.base_y = e.y
			if e.age>=.72: capture(s,r,e)
			continue
		if SHIPS.has(e.kind):
			if e.age<7: e.x = maxf(e.x,MonsterCatalog.ANCHOR+130)
			else: e.x -= r.speed*dt
			e.shot -= dt
			if e.shot<=0 and e.x<r.view_right+20 and e.x>MonsterCatalog.ANCHOR+50:
				e.shot = 3.1 if r.active_count()<16 else 2.1
				if e.kind in ["fighter","saucer","ghost_frigate"]:
					s.add_object("beam",e.x-30,clampf(s.y-55,225,510),{"speed":0.0,"contacts":{},"hit_at":-10.0})
				elif e.kind=="cargo": s.add_object("meteor",e.x-30,e.y+65,{"speed":.9,"radius":32.0,"variant":1})
			var lead = r.leader_index()
			if lead<0: return
			var point = Vector2(e.x,e.y)
			if s.dash_left>0 and int(e.last_dash)!=s.dash_serial and point.distance_to(Vector2(r.members[lead].x,r.members[lead].y-55))<150:
				e.last_dash = s.dash_serial;hit_ship(s,r,e,clampi(int(r.active_count()/maxi(1,int(e.need))),1,3))
			elif s.dash_left<=0 and float(e.age)-float(e.hit_at)>.6:
				var index = nearest_member(r,point,100)
				if hurt(s,r,index,"space_ship",point): e.hit_at = e.age
			continue
		if e.kind in ["acid","friendly_shot"]:
			for ship in s.objects:
				if not ship.taken and SHIPS.has(ship.kind) and Vector2(e.x,e.y).distance_to(Vector2(ship.x,ship.y))<100:
					hit_ship(s,r,ship);e.taken = true;break
			if e.age>2.5: e.taken = true
			continue
		if e.kind=="beam":
			if e.age>=.8 and e.age<=1.5 and float(e.age)-float(e.hit_at)>.32:
				for i in range(r.members.size()):
					var m = r.members[i]
					if e.contacts.has(int(m.id)) or float(m.x)>float(e.x): continue
					if absf(float(m.y)-55-float(e.y))<24:
						if hurt(s,r,i,"space_laser",Vector2(m.x,e.y)): e.contacts[int(m.id)] = true;e.hit_at = e.age
						break
			if e.age>1.55: e.taken = true
			continue
		var radius = float(e.radius)+24
		if e.kind=="coin": radius = 175 if r.run_items.has("coin_magnet") else 58
		var index = nearest_member(r,Vector2(e.x,e.y),radius)
		if index<0: continue
		match e.kind:
			"coin":
				e.taken = true;r.coins += 2;s.collected += 2;r.collect_coin_row(e)
				r.events.append({"type":"coin","amount":2,"x":e.x,"y":e.y,"physical_pickup":true})
			"astronaut","pod":
				e.state = "capture";e.age = 0;r.members[index].attack_left = .72;r.members[index].attack_duration = .72
				r.events.append({"type":"space_capture","x":e.x,"y":e.y})
			"core","energy","fuel":
				e.taken = true;s.charge = minf(100,s.charge+22)
				if e.kind=="fuel": s.left = minf(s.duration+8-s.flight_age,s.left+1.5)
				r.events.append({"type":"space_energy","x":e.x,"y":e.y})
			"alien_power","orbital_power": e.taken = true;give_power(s,r,7 if e.kind=="alien_power" else 8)
			"eye": e.taken = true;r.eyes_collected += 1;r.events.append({"type":"eye","x":e.x,"y":e.y})
			"monolith":
				e.taken = true;r.coins += 40;s.charge = 100
				r.events.append({"type":"coin","amount":40,"x":e.x,"y":e.y});r.events.append({"type":"space_discovery","title":"2001 ALMAS • ROTA SECRETA!"})
			"drone":
				e.taken = true;s.charge = minf(100,s.charge+15);shield_charges = maxi(shield_charges,1);power_kind = 8;power_left = maxf(power_left,5)
				if pilot_left>0: pilot_hp = mini(3,pilot_hp+1)
			"meteor","satellite","parasite","egg","shot":
				if s.dash_left>0 or power_kind==7:
					e.taken = true;s.charge = minf(100,s.charge+9);r.events.append({"type":"space_smash","x":e.x,"y":e.y})
				elif hurt(s,r,index,"space_"+str(e.kind),Vector2(e.x,e.y)): e.taken = true
		if r.dead: return
	for i in range(s.objects.size()-1,-1,-1):
		var e = s.objects[i]
		if e.taken or e.x<r.view_left-400:
			if not e.taken: r.miss_coin_row(e)
			s.objects.remove_at(i)

func paint_object(g,s,e: Dictionary,alpha: float) -> bool:
	var c = g.paint_target;var p = Vector2(e.x,e.y);var tint = Color(1,1,1,alpha)
	if SHIPS.has(e.kind):
		var spec: Dictionary = SHIPS[e.kind];var damaged = int(e.hp)<int(e.max_hp)
		art.sprite(c,"fleet",int(spec.frame)+(1 if damaged else 0),p,float(spec.size),sin(float(e.age)*1.4)*.035,tint)
		var bar = Rect2(p+Vector2(-65,-float(spec.size)*.37),Vector2(130,5));c.draw_rect(bar,Color(.1,.06,.15,alpha));bar.size.x *= float(e.hp)/float(e.max_hp);c.draw_rect(bar,Color(.6,1,.75,alpha))
		g.home_menu.label(g,"FORÇA %d • MOTOR %d" % [int(spec.need),int(e.hp)],p+Vector2(0,-float(spec.size)*.40),13,g.CREAM,true,210)
		return true
	if e.kind=="beam":
		var warning = float(e.age)<.8
		var color = Color(1,.25,.25,(.25+.2*sin(float(e.age)*24))*alpha) if warning else Color(1,.35,.35,.9*alpha)
		c.draw_line(Vector2(g.runner.view_left,e.y),p,color,2 if warning else 12,true)
		if warning: g.home_menu.label(g,"!",p+Vector2(-30,-15),24,g.CORAL,true)
		return true
	if e.kind in ["shot","acid","friendly_shot"]:
		c.draw_circle(p,8,Color(.55,1,.25,alpha) if e.kind=="acid" else Color(.45,.9,1,alpha));c.draw_line(p,p+Vector2(-25,0),Color(.55,1,.5,alpha*.45),6,true);return true
	if e.kind=="drone": art.sprite(c,"fleet",10+posmod(int(float(e.age)*4),2),p,110,sin(float(e.age)*3)*.1,tint);return true
	if e.kind in ["alien_power","orbital_power","fuel","core"]:
		var frame = {"alien_power":12,"orbital_power":13,"fuel":14,"core":15}[e.kind]
		art.sprite(c,"fleet",frame,p,72,sin(float(e.age)*3)*.08,tint);return true
	if e.kind=="eye": g.hub.eye(g,p,34);return true
	return false

func paint_party(g,s) -> void:
	var point = Vector2(MonsterCatalog.ANCHOR+25,s.y-55)
	if pilot_left>0:
		art.sprite(g.paint_target,"fleet",int(SHIPS[pilot_kind].frame),point,260,s.vy*.0003)
		g.home_menu.label(g,"NAVE TOMADA • %d s • CASCO %d" % [ceili(pilot_left),pilot_hp],point+Vector2(0,-100),16,g.MINT,true,350)
	if power_kind==7:
		art.sprite(g.paint_target,"helpers",12+posmod(int(s.age*7),4),point+Vector2(60,-60),100,sin(s.age*3)*.1)
	if power_kind==8 and shield_charges>0:
		g.paint_target.draw_arc(point,125,-2.6,1.4,36,Color(.35,.8,1,.65),4,true)
