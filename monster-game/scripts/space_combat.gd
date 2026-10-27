extends RefCounted
## Paced encounters and bounded, telegraphed attacks. All collisions use real members.
const SHIPS = {
	"tour_bus":{"frame":0,"hp":2,"need":2,"crew":3,"size":245.0,"label":"EXCURSÃO ORBITAL"},
	"cargo":{"frame":2,"hp":3,"need":5,"crew":2,"size":280.0,"label":"CARGUEIRO INFECTADO"},
	"saucer":{"frame":4,"hp":3,"need":7,"crew":2,"size":245.0,"label":"DISCO DE INVASÃO"},
	"fighter":{"frame":6,"hp":2,"need":4,"crew":1,"size":230.0,"label":"CAÇA DE SUCATA"},
	"ghost_frigate":{"frame":8,"hp":5,"need":12,"crew":4,"size":330.0,"label":"FRAGATA DO HORIZONTE"}
}
const LASER_WARNING = 1.25
const LASER_END = 1.85
var art = preload("res://scripts/adventure_art.gd").new()
var deck: Array[String] = []
var deck_zone = -1
var serial = 0
var shot_clock = 0.0
var destroyed = 0
var power_left = 0.0
var power_kind = -1
var shield_charges = 0
var pilot_left = 0.0
var pilot_kind = ""
var pilot_hp = 0
var pilot_hit_left = 0.0
var last_hit = -10.0
var encounters: Array[Dictionary] = []

func reset() -> void:
	deck.clear();deck_zone = -1;serial = 0;shot_clock = 0;destroyed = 0
	power_left = 0;power_kind = -1;shield_charges = 0;pilot_left = 0;pilot_kind = "";pilot_hp = 0;pilot_hit_left = 0;last_hit = -10;encounters.clear()

func scroll_speed(r) -> float:
	# Ground distance/tunnels continue independently. Space stays readable at high tunnels.
	return clampf((r.view_right-r.view_left)*.27,280,460)

func spawn_ship(s,r,kind: String,at_x: float,at_y: float) -> Dictionary:
	var spec: Dictionary = SHIPS[kind]
	return s.add_object(kind,at_x,at_y,{"hp":spec.hp,"max_hp":spec.hp,"need":spec.need,"radius":78.0,"speed":1.0,"shot":2.4,"last_dash":-1,"hit_at":-10.0})

func hostile(e: Dictionary) -> bool:
	return SHIPS.has(e.kind) or e.kind in ["meteor","parasite","beam","satellite","egg","shot","vortex","gate","rock"]

func refill_deck(layer: int) -> void:
	# Reward encounters between threats; later layers introduce a different family.
	var sequences = [
		["tour_bus","rescue","meteor","coins","fighter","rescue"],
		["cargo","coins","meteor","rescue","corridor","drone"],
		["saucer","rescue","parasite","coins","egg","drone"],
		["ghost_frigate","coins","vortex","rescue","corridor","fighter","drone"]
	]
	deck.assign(sequences[layer]);deck_zone = layer

func spawn(s,r) -> void:
	if s.objects.size()>42: return
	var layer = s.zone()
	if deck.is_empty() or deck_zone!=layer: refill_deck(layer)
	var kind = str(deck[0])
	# Keep one primary threat near the party; a new one waits behind it.
	var ahead = 0
	for e in s.objects:
		if not e.taken and hostile(e) and e.x>MonsterCatalog.ANCHOR-80: ahead += 1
	if kind not in ["rescue","coins","drone"] and ahead>=(2 if r.active_count()>=20 else 1): return
	deck.pop_front();serial += 1
	var x = r.view_right+130
	var lane = [325.0,460.0,385.0][(serial-1)%3]
	encounters.append({"kind":kind,"layer":layer,"time":s.flight_age})
	if encounters.size()>80: encounters.pop_front()
	if SHIPS.has(kind):
		spawn_ship(s,r,kind,x,lane)
	elif kind=="meteor":
		s.add_object("meteor",x,lane,{"variant":serial%3,"radius":31.0,"speed":1.0,"vy":19.0 if lane<400 else -19.0})
		if r.active_count()>=20: s.add_object("meteor",x+210,530 if lane<400 else 280,{"variant":1,"radius":28.0,"speed":1.0,"vy":-12.0})
	elif kind=="parasite":
		s.add_object("parasite",x,lane,{"radius":29.0,"speed":.9})
		if r.active_count()>=20: s.add_object("parasite",x+205,lane+65,{"radius":29.0,"speed":.9})
	elif kind=="egg": s.add_object("egg",x,lane,{"radius":33.0,"speed":.75})
	elif kind=="corridor":
		var at_y = 320.0 if serial%2==0 else 485.0
		s.add_object("beam",r.view_right-90,at_y,{"radius":19.0,"speed":0.0,"contacts":{},"hit_at":-10.0,"length":minf(780,r.view_right-r.view_left-170)})
	elif kind=="vortex": s.add_object("vortex",x,360,{"radius":30.0,"speed":.65})
	elif kind=="drone": s.add_object("drone",x,lane,{"radius":30.0,"speed":.9})
	if kind=="rescue": s.add_object("astronaut",x+100,lane,{"radius":36.0,"speed":.9})
	# Each row gives a safe route around the threat, rather than covering its hull.
	var coin_lane = lane if kind in ["rescue","coins","drone"] else 510.0 if lane<400 else 285.0
	var row = r.new_coin_row(5)
	for i in range(5): s.add_object("coin",x+135+i*63,coin_lane+sin(i*.7)*18,{"radius":20.0,"coin_row":row,"speed":.95})
	if serial%3==0: s.add_object("core",x+470,coin_lane,{"radius":27.0,"speed":.95})
	if serial%4==0:
		var choices = ["fuel"]
		if 7 in r.power_owned: choices.append("alien_power")
		if 8 in r.power_owned: choices.append("orbital_power")
		s.add_object(choices[posmod(int(serial/4),choices.size())],x+540,coin_lane,{"radius":29.0,"speed":.95})
	if serial%11==0: s.add_object("eye",x+650,coin_lane,{"radius":23.0,"speed":.95})

func give_power(s,r,kind: int) -> void:
	power_kind = kind;shield_charges = 3 if kind==8 else 0
	power_left = (7.0+int(r.power_levels.get("alien_time",0))*2) if kind==7 else (8.0+int(r.power_levels.get("orbital_time",0))*2)
	r.events.append({"type":"space_discovery","title":"SIMBIONTE CÓSMICO" if kind==7 else "ESCUDO ORBITAL • 3 CARGAS"})

func member_centre(r,index: int) -> Vector2:
	var m = r.members[index]
	return Vector2(m.x+r.space.member_height(r)*.12,m.y-r.space.member_height(r)*.5)

func nearest_member(r,point: Vector2,radius: float) -> int:
	if pilot_left>0:
		var offset = point-Vector2(r.space.x+25,r.space.y-48)
		if Vector2(offset.x/1.55,offset.y).length()<radius+38: return r.leader_index()
		return -1
	var index = -1;var best = radius
	for i in range(r.members.size()):
		if r.members[i].falling: continue
		var d = member_centre(r,i).distance_to(point)
		if d<best: best = d;index = i
	return index

func hurt(s,r,index: int,cause: String,point: Vector2,ignores_dash: bool = false) -> bool:
	if index<0 or s.phase!="flight" or s.age-last_hit<.45 or (s.dash_left>0 and not ignores_dash): return false
	if shield_charges>0 and power_left>0:
		shield_charges -= 1;last_hit = s.age
		r.events.append({"type":"spectral_guard","x":point.x,"y":point.y})
		if shield_charges==0: power_left = 0
		return true
	if pilot_left>0 and pilot_hp>0:
		pilot_hp -= 1;last_hit = s.age;pilot_hit_left = .35
		if pilot_hp==0:
			pilot_left = 0;r.hit_grace = 1.0
			s.visual.notify("CASCO DESTRUÍDO • HORDA LIVRE",3)
		r.events.append({"type":"space_hit","x":point.x,"y":point.y});return true
	var before = r.active_count()
	if r.damage(index,cause):
		last_hit = s.age;s.hurt_left = .4;s.hits += 1
		if r.active_count()<before: s.visual.notify("-1 MEMBRO",3,1.15)
		r.events.append({"type":"space_hit","x":point.x,"y":point.y});return true
	return false

func capture(s,r,e: Dictionary) -> void:
	if e.taken: return
	e.taken = true;s.captured += 1;r.souls += 1;r.recruits += 1
	r.mission_stats.civilians = int(r.mission_stats.get("civilians",0))+1;r.mission_stats.space_captures = int(r.mission_stats.get("space_captures",0))+1
	var kind = r.recruit_kind();r.add_member(kind,false,Vector2(s.x-35,s.y))
	s.charge = minf(100,s.charge+16)
	r.events.append({"type":"soul","kind":kind,"x":e.x,"y":e.y,"soldier":false,"from_vehicle":false})

func destroy_ship(s,r,e: Dictionary) -> void:
	if e.taken: return
	e.taken = true;destroyed += 1;s.charge = minf(100,s.charge+24)
	r.coins += 8;r.events.append({"type":"coin","amount":8,"x":e.x,"y":e.y})
	r.events.append({"type":"space_smash","x":e.x,"y":e.y,"title":SHIPS[e.kind].label})
	r.mission_stats.space_ships = int(r.mission_stats.get("space_ships",0))+1
	s.add_object("wreck",e.x,e.y,{"ship":e.kind,"speed":.65,"radius":0.0})
	for i in range(maxi(0,int(SHIPS[e.kind].crew)-int(e.get("released_crew",0)))):
		s.add_object("astronaut",e.x+65+i*56,clampf(e.y+(i%2)*65,270,525),{"radius":35.0,"speed":.65,"seed":i*1.4,"grace":.45})
	# Piloting is an optional pickup in recovery encounters; destroying a target never changes controls.

	if e.kind=="cargo": s.add_object("core",e.x+155,e.y-55,{"radius":27.0,"speed":.7})
	if e.kind=="saucer": s.add_object("core",e.x+65,e.y+60,{"radius":27.0,"speed":.7})

func hit_ship(s,r,e: Dictionary,force: int = 1) -> void:
	if e.taken: return
	e.hp = int(e.hp)-force;e.flash = .18
	r.events.append({"type":"space_ship_hit","x":e.x,"y":e.y})
	if int(e.hp)<=0: destroy_ship(s,r,e)

func fire(s,r,acid: bool) -> void:
	var target: Dictionary = {};var nearest = INF
	for e in s.objects:
		if not e.taken and SHIPS.has(e.kind) and e.x>s.x+65 and e.x<nearest: target = e;nearest = e.x
	if target.is_empty(): return
	var origin = Vector2(s.x+85,s.y-48)
	var direction = (Vector2(target.x,target.y)-origin).normalized()
	s.add_object("acid" if acid else "friendly_shot",origin.x,origin.y,{"vx":direction.x*680,"vy":direction.y*680,"speed":0.0,"radius":12.0})

func laser_segment(e: Dictionary) -> Vector2:
	return Vector2(float(e.x)-float(e.get("length",650)),float(e.x)-26)

func advance(s,r,dt: float) -> void:
	var play_dt = dt if s.phase=="flight" else 0.0
	power_left = maxf(0,power_left-play_dt);pilot_hit_left = maxf(0,pilot_hit_left-dt)
	var was_pilot = pilot_left>0
	pilot_left = maxf(0,pilot_left-play_dt)
	if was_pilot and pilot_left<=0:
		r.hit_grace = maxf(r.hit_grace,.8);s.visual.notify("HORDA LIVRE",2,1.2)
	if power_left<=0: power_kind = -1;shield_charges = 0
	shot_clock -= play_dt
	if s.phase=="flight" and (power_kind==7 or pilot_left>0) and shot_clock<=0:
		fire(s,r,power_kind==7);shot_clock = .7 if power_kind==7 else .6
	var speed = scroll_speed(r)
	for e in s.objects.duplicate():
		if e.taken: continue
		e.previous_x = e.x;e.previous_y = e.y
		e.age += dt;e.angle += float(e.spin)*dt;e.flash = maxf(0,float(e.get("flash",0))-dt)
		if e.kind in ["shot","acid","friendly_shot"]:
			e.x += float(e.vx)*dt;e.base_y += float(e.vy)*dt;e.y = e.base_y
		else:
			e.x -= speed*float(e.speed)*dt
			if e.kind=="meteor": e.base_y += float(e.get("vy",0))*dt
			if s.phase=="boost": e.base_y += s.climb_speed*dt*.55
			e.y = float(e.base_y)+sin(float(e.age)*1.6+float(e.seed))*(2 if e.kind=="coin" else 19 if SHIPS.has(e.kind) else 5)
		if e.kind=="gate":
			e.y = float(e.base_y)+sin(float(e.age)*1.15+float(e.seed))*float(e.get("motion",0))
			for centre in s.contacts.gate_parts(e):
				s.contacts.push(s,r,e,centre,63,"space_gate",3 if r.active_count()>=20 else 2)
			continue
		if e.kind=="rock":
			s.contacts.push(s,r,e,Vector2(e.x,e.y),float(e.radius),"space_rock")
			continue
		if e.kind=="exit":
			if s.phase=="flight" and s.charge>=100 and nearest_member(r,Vector2(e.x,e.y),65)>=0:
				e.taken = true;s.boost(r)
			continue
		if e.kind=="wreck":
			if e.age>.58: e.taken = true
			continue
		if e.kind=="vortex" and s.phase=="flight":
			var pull = clampf(1-absf(float(e.x)-s.x)/420,0,1)
			s.y += clampf(float(e.y)+42-s.y,-85,85)*dt*pull*.75
			if nearest_member(r,Vector2(e.x,e.y),35)>=0:
				hurt(s,r,nearest_member(r,Vector2(e.x,e.y),35),"space_vortex",Vector2(e.x,e.y))
			continue
		if e.kind=="parasite" and e.age>1 and e.x<s.x+320:
			e.state = "attack";e.base_y = move_toward(e.base_y,s.y-45,dt*24)
		if e.kind=="egg" and e.x<r.view_right-70:
			if e.state=="normal": e.state = "opening";e.hatch_at = e.age+1.25
			if e.age>=float(e.get("hatch_at",1e6)):
				e.state = "open"
				if e.age>float(e.hatch_at)+.35:
					e.taken = true;s.add_object("parasite",e.x,e.y,{"radius":30.0,"speed":.9,"state":"attack"});continue
		if e.state=="capture":
			var lead = r.leader_index()
			if lead<0: return
			e.x = move_toward(e.x,r.members[lead].x+20,dt*240);e.y = move_toward(e.y,s.y-45,dt*140);e.base_y = e.y
			if e.age>=.72: capture(s,r,e)
			continue
		if SHIPS.has(e.kind):
			if bool(e.get("counter",false)):
				e.core_open = e.age>=1.65 and e.age<4.15
				if e.age<.8: e.lock_y = lerpf(float(e.lock_y),s.y-s.member_height(r)*.5,dt*2)
				if s.phase=="flight" and e.age>=1.15 and not bool(e.fired):
					e.fired = true
					for j in range(2):
						s.add_object("shot",e.x-72+j*38,float(e.lock_y),{"vx":-390.0,"vy":0.0,"radius":13.0,"speed":0.0,"arm_left":.35})
			e.shot -= dt
			if e.shot<=0 and e.x<r.view_right-70 and e.x>MonsterCatalog.ANCHOR+200 and s.phase=="flight":
				e.shot = 3.8 if r.active_count()<16 else 2.8
				if e.kind in ["fighter","saucer","ghost_frigate"]:
					var origin = Vector2(e.x-72,e.y)
					var target = Vector2(s.x,s.y-45)
					var direction = (target-origin).normalized()
					s.add_object("shot",origin.x,origin.y,{"vx":direction.x*260,"vy":direction.y*260,"radius":13.0,"speed":0.0,"arm_left":.55})
			var lead = r.leader_index()
			if lead<0: return
			var point = Vector2(e.x,e.y)
			var attack_point = Vector2(s.x+25,s.y-48) if pilot_left>0 else member_centre(r,lead)
			if s.dash_left>0 and int(e.last_dash)!=s.dash_serial and point.distance_to(attack_point)<135:
				e.last_dash = s.dash_serial
				if bool(e.get("counter",false)) and not bool(e.get("core_open",false)):
					hurt(s,r,lead,"space_shield",attack_point,true);s.dash_left = 0
					s.visual.notify("ESCUDO FECHADO • ESPERE O NÚCLEO",3,1.4)
				else:
					var damage = int(e.max_hp) if r.active_count()>=int(e.need) else 1
					hit_ship(s,r,e,damage);s.chain_hit(r)
			if not e.taken:
				s.contacts.push(s,r,e,point,76,"space_ship")

			continue
		if e.kind in ["acid","friendly_shot"]:
			for ship in s.objects:
				if not ship.taken and SHIPS.has(ship.kind) and Vector2(e.x,e.y).distance_to(Vector2(ship.x,ship.y))<82:
					if not bool(ship.get("counter",false)) or bool(ship.get("core_open",false)): hit_ship(s,r,ship)
					e.taken = true;break
			if e.age>2.5: e.taken = true
			continue
		if e.kind=="beam":
			var hit_limit = 2 if r.active_count()>=16 else 1
			if e.age>=LASER_WARNING and e.age<=LASER_END and float(e.age)-float(e.hit_at)>.5 and int(e.get("damage_count",0))<hit_limit:
				var span = laser_segment(e)
				if pilot_left>0:
					var hull = Vector2(s.x+25,s.y-48)
					if hull.x+140>=span.x and hull.x-140<=span.y and absf(hull.y-float(e.y))<59 and not e.contacts.has("hull"):
						if hurt(s,r,r.leader_index(),"space_laser",hull):
							e.contacts.hull = true;e.hit_at = e.age;e.damage_count = hit_limit
				else:
					for i in range(r.members.size()):
						var m = r.members[i];var centre = member_centre(r,i)
						if e.contacts.has(int(m.id)) or centre.x<span.x or centre.x>span.y: continue
						if absf(centre.y-float(e.y))<22:
							if hurt(s,r,i,"space_laser",centre):
								e.contacts[int(m.id)] = true;e.hit_at = e.age;e.damage_count = int(e.get("damage_count",0))+1
							break
			if e.age>LASER_END+.1: e.taken = true
			continue
		if e.kind=="shot" and e.age<float(e.get("arm_left",0)): continue
		var radius = float(e.radius)+19
		if e.kind=="coin": radius = 175 if r.run_items.has("coin_magnet") else 43
		var index = nearest_member(r,Vector2(e.x,e.y),radius)
		if index<0: continue
		match e.kind:
			"coin":
				e.taken = true;r.coins += 2;s.collected += 2;s.charge = minf(100,s.charge+1.5)
				var id = int(e.get("coin_row",-1));var row = r.coin_rows.get(id,{})
				var completed = not row.is_empty() and int(row.total)>=3 and int(row.collected)+1>=int(row.total)
				r.collect_coin_row(e)
				if completed and not s.perfect_rows.has(id): s.perfect_rows[id] = true;s.charge = minf(100,s.charge+10)

				r.events.append({"type":"coin","amount":2,"x":e.x,"y":e.y,"physical_pickup":true})
			"astronaut","pod":
				if e.age<float(e.get("grace",0)): continue
				e.state = "capture";e.age = 0;r.members[index].attack_left = .72;r.members[index].attack_duration = .72
				r.events.append({"type":"space_capture","x":e.x,"y":e.y})
			"core","energy","fuel":
				e.taken = true;s.charge = minf(100,s.charge+18)
				if e.kind=="fuel": s.left = minf(s.duration+8-s.flight_age,s.left+1.5)
				r.events.append({"type":"space_energy","x":e.x,"y":e.y})
			"boarding":
				e.taken = true;pilot_kind = str(e.get("ship","tour_bus"));pilot_left = 5.0;pilot_hp = 3;shot_clock = .45
				r.hit_grace = maxf(r.hit_grace,.65);s.visual.notify("NAVE • MESMO CONTROLE • 3 DE CASCO",3,2.0)
			"alien_power","orbital_power": e.taken = true;give_power(s,r,7 if e.kind=="alien_power" else 8)
			"eye": e.taken = true;r.eyes_collected += 1;r.events.append({"type":"eye","x":e.x,"y":e.y})
			"monolith":
				e.taken = true;r.coins += 40;s.charge = 100
				r.events.append({"type":"coin","amount":40,"x":e.x,"y":e.y});r.events.append({"type":"space_discovery","title":"2001 ALMAS • ROTA SECRETA"})
			"drone":
				e.taken = true;s.charge = minf(100,s.charge+12);shield_charges = maxi(shield_charges,1);power_kind = 8;power_left = maxf(power_left,5)
				if pilot_left>0: pilot_hp = mini(3,pilot_hp+1)
				s.visual.notify("REPARO ORBITAL",2,1.5)
			"meteor","satellite","parasite","egg","shot":
				if s.dash_left>0 or power_kind==7:
					e.taken = true;s.charge = minf(100,s.charge+7)
					if s.dash_left>0: s.chain_hit(r)
					r.events.append({"type":"space_smash","x":e.x,"y":e.y})
				elif hurt(s,r,index,"space_"+str(e.kind),Vector2(e.x,e.y)): e.taken = true
		if r.dead: return
	for i in range(s.objects.size()-1,-1,-1):
		var e = s.objects[i]
		if e.taken or e.x<r.view_left-220 or e.y>720+240 or (e.kind in ["shot","friendly_shot","acid"] and e.age>4):
			if not e.taken: r.miss_coin_row(e)
			s.objects.remove_at(i)

func paint_object(g,s,e: Dictionary,alpha: float) -> bool:
	var c = g.paint_target;var p = Vector2(e.x,e.y);var tint = Color(1,1,1,alpha)
	if SHIPS.has(e.kind):
		var spec: Dictionary = SHIPS[e.kind]
		var flash = float(e.get("flash",0))>0
		s.atmosphere.exhaust(g,s,e,float(spec.size))
		# Same hull registration at every HP; damage never replaces the whole geometry.
		art.sprite(c,"fleet",int(spec.frame),p,float(spec.size),sin(float(e.age)*1.4+float(e.seed))*.045,Color(1,.78,.7,alpha) if flash else tint)
		s.life.ship_details(g,s,e,float(spec.size),alpha)
		if bool(e.get("counter",false)):
			var open = bool(e.get("core_open",false))
			if not open:
				c.draw_arc(p,88,-1.6,1.6,32,Color(.85,.35,.65,.55*alpha),4,true)
				if float(e.age)<1.15:
					for j in range(8):
						var xx = p.x-90-j*50
						c.draw_line(Vector2(xx,e.lock_y),Vector2(xx-19,e.lock_y),Color(1,.55,.36,.5*alpha),2,true)
				s.visual.prop(g,"core",p+Vector2(-40,20),48,alpha*.38)
			else:
				s.visual.prop(g,"core",p+Vector2(-45,10),66,alpha)
				c.draw_arc(p+Vector2(-45,10),39,s.age*2,s.age*2+TAU*.7,24,Color(.35,1,.7,.9*alpha),2,true)
		var bar = Rect2(p+Vector2(-49,-float(spec.size)*.36),Vector2(98,5))
		c.draw_rect(bar,Color(.1,.06,.15,alpha));bar.size.x *= float(e.hp)/float(e.max_hp);c.draw_rect(bar,Color(.97,.55,.38,alpha))
		g.home_menu.label(g,"%d+" % int(spec.need),p+Vector2(0,-float(spec.size)*.40),16,g.CREAM,true,100)
		if int(e.hp)<int(e.max_hp):
			for i in range(3):
				var t = fposmod(float(e.age)*.8+i*.33,1)
				c.draw_circle(p+Vector2(36+t*14,-32-t*48),4+t*6,Color(.32,.27,.36,(1-t)*.33*alpha))
		return true
	if e.kind=="gate":
		var parts = s.contacts.gate_parts(e)
		for i in range(parts.size()):
			var centre: Vector2 = parts[i]
			var pulse = .14+maxf(0,sin(float(e.age)*7+i))* .10
			c.draw_circle(centre,62,Color(1,.18,.11,pulse*alpha))
			s.visual.prop(g,"mine",centre,136,alpha,sin(float(e.age)*.9+float(e.seed)+i)*.14)
			# A small attached warning light breathes; no floating placeholder walls.
			c.draw_circle(centre+Vector2(-5,30),3.5,Color(1,.35,.15,(.5+pulse)*alpha))
		return true
	if e.kind=="rock": s.visual.prop(g,"rock",p,134,alpha,e.angle*.1);return true
	if e.kind=="exit":
		s.visual.prop(g,"portal",p,225,alpha,PI*.5)
		for j in range(6):
			var angle = s.age*1.3+j*TAU/6
			c.draw_circle(p+Vector2(cos(angle)*50,sin(angle)*86),2.5,Color(.55,1,.85,alpha*.7))
		g.home_menu.label(g,"SUBIR",p+Vector2(0,-119),17,g.MINT,true,130)
		return true
	if e.kind=="boarding":
		art.sprite(c,"fleet",0,p,135,0,tint)
		c.draw_arc(p,62,0,TAU,32,Color(.4,.9,1,.65*alpha),2,true)
		g.home_menu.label(g,"PILOTAR",p+Vector2(0,-58),13,g.MINT,true,130)
		return true
	if e.kind=="wreck":
		var spec: Dictionary = SHIPS[e.ship];var t = clampf(float(e.age)/.58,0,1)
		var colour = Color(1,.64,.34,(1-t)*alpha)
		if t<.35: c.draw_circle(p,22+t*65,Color(1,.8,.45,(1-t/.35)*.34*alpha))
		art.sprite(c,"fleet",int(spec.frame)+1,p+Vector2(-t*25,t*t*90),float(spec.size)*(1-t*.25),t*.55,Color(.7,.65,.7,(1-t)*(1-t)*alpha))
		for j in range(7):
			var direction = Vector2.from_angle(j*TAU/7+float(e.seed))
			var at = p+direction*(12+t*90)
			c.draw_line(at,at+direction*7,colour,2.8,true)
		return true
	if e.kind=="beam":
		var warning = float(e.age)<LASER_WARNING;var span = laser_segment(e)
		var emitter = Vector2(e.x,e.y)
		art.sprite(c,"fleet",10,emitter,85,PI,tint)
		c.draw_circle(emitter+Vector2(-22,0),10,Color(1,.3,.2,(.35+sin(e.age*14)*.12)*alpha))
		if warning:
			for i in range(ceili((span.y-span.x)/25)):
				var x = span.x+i*25
				c.draw_line(Vector2(x,e.y),Vector2(minf(x+11,span.y),e.y),Color(1,.55,.3,.45*alpha),2,true)
			g.home_menu.label(g,"LASER",emitter+Vector2(-15,-48),14,g.CORAL,true,100)
		else:
			c.draw_line(Vector2(span.x,e.y),Vector2(span.y,e.y),Color(1,.24,.15,.17*alpha),18,true)
			c.draw_line(Vector2(span.x,e.y),Vector2(span.y,e.y),Color(1,.45,.3,.9*alpha),6,true)
			c.draw_line(Vector2(span.x,e.y),Vector2(span.y,e.y),Color(1,.92,.7,alpha),2,true)
		return true
	if e.kind in ["shot","acid","friendly_shot"]:
		var color = Color(.65,1,.3,alpha) if e.kind=="acid" else Color(1,.4,.28,alpha) if e.kind=="shot" else Color(.45,.9,1,alpha)
		c.draw_circle(p,6,color);c.draw_line(p,p-Vector2(float(e.vx),float(e.vy)).normalized()*20,Color(color,.4*alpha),4,true)
		return true
	if e.kind=="vortex": s.visual.vortex(g,s,p,180,alpha);return true
	if e.kind=="drone":
		c.draw_arc(p,40,0,TAU,28,Color(.4,.9,1,.4*alpha),2,true)
		art.sprite(c,"fleet",10+posmod(int(float(e.age)*3),2),p,83,sin(float(e.age)*2)*.05,tint)
		g.home_menu.label(g,"+",p+Vector2(0,-43),25,g.MINT,true)
		return true
	if e.kind in ["alien_power","orbital_power","fuel","core"]:
		var frame = {"alien_power":12,"orbital_power":13,"fuel":14,"core":15}[e.kind]
		c.draw_circle(p,36,Color(.45,.9,1,.065*alpha))
		art.sprite(c,"fleet",frame,p,60,sin(float(e.age)*2)*.045,tint)
		return true
	if e.kind=="eye": g.hub.eye(g,p,31);return true
	return false

func paint_party(g,s) -> void:
	var point = Vector2(s.x+25,s.y-48)
	if pilot_left>0: s.visual.cabin(g,s)
	if power_kind==7: art.sprite(g.paint_target,"helpers",12+posmod(int(s.age*5),4),point+Vector2(70,-72),76,sin(s.age*2)*.06)
	if power_kind==8 and shield_charges>0:
		var bounds = Rect2(point-Vector2(150,85),Vector2(300,170))
		if pilot_left<=0 and not g.runner.members.is_empty():
			bounds = Rect2(member_centre(g.runner,0),Vector2.ONE)
			for i in range(g.runner.members.size()): bounds = bounds.expand(member_centre(g.runner,i))
			bounds = bounds.grow(s.member_height(g.runner)*.57)
		g.paint_target.draw_set_transform(bounds.get_center(),0,bounds.size/208)
		for j in range(3):
			var start = s.age*.65+j*TAU/3
			g.paint_target.draw_arc(Vector2.ZERO,104,start,start+TAU*.20,18,Color(.35,.8,1,.22+sin(s.age*3+j)*.06),1.7,true)
		g.paint_target.draw_set_transform(Vector2.ZERO)
