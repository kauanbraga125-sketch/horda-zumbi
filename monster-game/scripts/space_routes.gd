extends RefCounted
## Authored route fragments. Time to contact, not screen width, sets reaction time.
var serial = 0
var encounter_age = 0.0
var current = ""
var history: Array[Dictionary] = []
var exit_spawned = false
var enabled = true
var layer_step = 0
var last_layer = -1
const DECKS = [
	["rescue", "convoy", "gates", "recovery", "counterattack"],
	["slalom", "convoy", "gates", "recovery", "counterattack"],
	["counterattack", "rescue", "slalom", "recovery", "convoy"],
	["gravity", "counterattack", "gates", "recovery", "elite"]
]

func reset() -> void:
	serial = 0;encounter_age = 0;current = "";history.clear();exit_spawned = false;enabled = true;layer_step = 0;last_layer = -1

func at(s,r,seconds: float, speed: float = 1.0) -> float:
	return maxf(s.x+330,s.x+s.battle.scroll_speed(r)*speed*seconds)

func object(s,kind: String,x: float,y: float,extra: Dictionary = {}) -> Dictionary:
	extra["encounter"] = serial
	return s.add_object(kind,x,y,extra)

func row(s,r,x: float,y: float,rise: float = 0) -> void:
	var id = r.new_coin_row(5)
	for i in range(5): object(s,"coin",x+i*56,y+sin(i*.42)*rise,{"coin_row":id,"speed":1.0})

func start(s,r,kind: String = "") -> void:
	serial += 1;encounter_age = 0
	if s.zone()!=last_layer: layer_step = 0;last_layer = s.zone()
	current = kind if not kind.is_empty() else str(DECKS[s.zone()][layer_step%5])
	layer_step += 1
	var side = 1 if s.random.randi_range(0,1)==0 else -1
	var safe = 355.0+side*105;var risky = 355.0-side*100
	var x = at(s,r,2.7)
	history.append({"kind":current,"layer":s.zone(),"time":s.flight_age,"members":r.active_count()})
	if history.size()>100: history.pop_front()
	s.battle.encounters.append(history[-1].duplicate())
	match current:
		"rescue":
			row(s,r,x,safe,-side*32)
			object(s,"astronaut",x+150,risky,{"radius":35.0})
			object(s,"meteor",x+90,risky+side*89,{"variant":serial%3,"radius":28.0,"speed":1.0})
			object(s,"pod" if s.zone()>0 else "astronaut",x+330,risky+side*38,{"radius":35.0})
			if serial==1: s.visual.notify("ARRASTE LIVREMENTE • RESGATE ALMAS",1,2.4)
		"gates","slalom":
			for i in range(2 if current=="gates" else 3):
				var centre = 350.0+side*(75 if i%2==0 else -75)
				object(s,"gate",x+i*340,centre,{"gap":178.0 if serial<=2 else 158.0,"motion":24.0 if s.zone()>0 else 10.0,"speed":1.0,"contacts":{},"damage_count":0})
				row(s,r,x+i*340+35,centre,side*12)
			object(s,"astronaut",x+420,350-side*65,{"radius":35.0})
			s.visual.notify("MINAS À DERIVA • PROTEJA A CAUDA",1,1.8)
		"convoy","elite":
			for i in range(3 if current=="elite" else 2):
				var ship = s.battle.spawn_ship(s,r,"ghost_frigate" if current=="elite" and i==2 else "fighter" if i==1 else "cargo" if s.zone()==1 else "tour_bus",x+i*235,355+side*i*43)
				ship.encounter = serial;ship.speed = 1.0;ship.shot = 99.0;ship.chain_target = true
			row(s,r,x+40,safe)
			object(s,"orbital_power" if 8 in r.power_owned else "core",x-160,safe,{"radius":30.0})
			s.visual.notify("COMBOIO • ACERTE E ENCADEIE INVESTIDAS",1,2.1)
		"counterattack":
			var ship = s.battle.spawn_ship(s,r,"saucer",at(s,r,4.1),risky)
			ship.encounter = serial;ship.speed = 1.0;ship.shot = 99.0;ship.counter = true;ship.fired = false;ship.lock_y = s.y-s.member_height(r)*.5
			row(s,r,x,safe)
			if s.zone()>=2: object(s,"egg",x+380,safe-80,{"radius":30.0,"speed":1.0})
			if s.zone()>=2: object(s,"parasite",x+620,risky-70,{"radius":29.0,"speed":1.18})
			object(s,"astronaut",float(ship.x)+180,risky,{"radius":35.0})
			s.visual.notify("DESVIE DO TIRO • ATAQUE O NÚCLEO VERDE",1,2.3)
		"gravity":
			object(s,"vortex",x+200,300+side*55,{"radius":30.0,"speed":1.0})
			row(s,r,x,480,-55)
			object(s,"astronaut",x+390,430,{"radius":35.0})
			object(s,"rock",x+70,235,{"radius":48.0,"speed":1.0})
			object(s,"core",x+500,440,{"radius":28.0})
		"recovery":
			row(s,r,x,360,38)
			object(s,"drone",x+280,390,{"radius":30.0})
			object(s,"astronaut",x+420,370,{"radius":35.0})
			if serial%2==0: object(s,"boarding",x+535,365,{"radius":32.0,"ship":"tour_bus"})
			if 7 in r.power_owned: object(s,"alien_power",x+160,390,{"radius":29.0})

func busy(s,r) -> bool:
	for e in s.objects:
		if not e.taken and int(e.get("encounter",-1))==serial and s.battle.hostile(e) and float(e.x)>r.view_left-100: return true
	return false

func advance(s,r,dt: float) -> void:
	if not enabled or s.phase!="flight": return
	encounter_age += dt
	if s.charge>=100 and not exit_spawned and (current.is_empty() or (encounter_age>4.6 and not busy(s,r))):
		exit_spawned = true
		object(s,"exit",at(s,r,2.0),350,{"radius":58.0,"speed":1.0})
		s.visual.notify("IMPULSO PRONTO • ENTRE NO PORTAL",3,2.6)
		return
	if exit_spawned:
		var exits = s.objects.filter(func(e):return not e.taken and e.kind=="exit")
		if exits.is_empty(): exit_spawned = false;current = "";encounter_age = 0
		return
	if current.is_empty() or (encounter_age>5.1 and not busy(s,r)):
		start(s,r)

func next_layer() -> void:
	current = "";encounter_age = 0;exit_spawned = false
