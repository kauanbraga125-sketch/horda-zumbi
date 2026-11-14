extends RefCounted
## One charged shot, one real target. No area damage or hidden reward path.
const Art = preload("res://scripts/bird_art.gd")
const MINT = Color("86ffe2")
const GROUND = ["bomb","air_bomb","crate","spikes","bullet"]
const WATER = ["rubble","barrel","rotor","collapse"]
const ORBIT = ["meteor","rock","satellite","parasite","egg","shot"]
var phase = "idle"
var age = 0.0
var until_shot = 60.0
var charge_seconds = .72
var mode = ""
var locked: Dictionary = {}
var impact = Vector2.ZERO
var aim = 0.0
var shots = 0

static func interval(level: int) -> float:return 60.0-(clampi(level,1,3)-1)*10.0

func reset(level: int) -> void:
	phase = "idle";age = 0;until_shot = interval(level);charge_seconds = .72;mode = ""
	locked = {};impact = Vector2.ZERO;aim = 0;shots = 0

func run_mode(r) -> String:
	if r.sky.active or r.transform_left>0:return "transition"
	if r.space.active:return "space" if r.space.phase=="flight" else "transition"
	if r.sewer.active:return "sewer" if r.sewer.phase=="ride" else "transition"
	return "street"

func objects(r) -> Array:
	return r.space.objects if r.space.active else r.sewer.objects if r.sewer.active else r.entities

func anchor(r) -> float:
	if mode=="space":return r.space.x
	if mode=="sewer" and not r.sewer.boats.is_empty():return float(r.sewer.boats.front().x)+r.sewer.HULL_HALF_WIDTH-12
	return r.ANCHOR

func front(e: Dictionary,r) -> float:
	var radius = float(e.get("radius",24)) if mode=="space" else float(e.get("width",48))*(1.0 if mode=="sewer" else .5)
	return float(e.x)-radius-anchor(r)

func eligible(e: Dictionary,r) -> bool:
	if e.get("taken",false) or e.get("state","normal") not in ["normal",""]:return false
	if mode=="street":return MonsterCatalog.VEHICLES.has(e.kind) or e.kind in GROUND
	if mode=="sewer":return e.kind in WATER
	return mode=="space" and (r.space.battle.SHIPS.has(e.kind) or e.kind in ORBIT)

func speed(e: Dictionary,r) -> float:
	if mode=="space":return r.space.battle.scroll_speed(r)*float(e.get("speed",1))+absf(float(e.get("vx",0)))
	if mode=="sewer":return r.sewer.scroll_speed(r)
	return maxf(1,r.speed-float(e.get("vx",0)))

func target_point(e: Dictionary,r) -> Vector2:
	if mode=="sewer":return r.sewer.object_surface(e)-Vector2(0,28)
	return Vector2(e.x,float(e.y)-float(e.get("height",70))*.5) if mode=="street" else Vector2(e.x,e.y)

func find_target(r) -> Dictionary:
	var chosen: Dictionary = {};var best = 850.0
	for e in objects(r):
		if not eligible(e,r) or e.x>=r.view_right-40:continue
		var delta = front(e,r)
		if delta>maxf(110,speed(e,r)*.28+60) and delta<best:best = delta;chosen = e
	return chosen

func cancel_charge() -> void:
	locked = {};phase = "idle";age = 0;aim = 0

func fire(bird,r) -> bool:
	# The held dictionary must still be a live member of this course, ahead of us.
	if locked.is_empty() or not objects(r).has(locked) or not eligible(locked,r) or front(locked,r)<=40:return false
	impact = target_point(locked,r)
	if mode=="space" and r.space.battle.SHIPS.has(locked.kind):
		r.space.battle.hit_ship(r.space,r,locked,maxi(1,int(locked.get("hp",1))))
	elif mode=="street" and MonsterCatalog.VEHICLES.has(locked.kind):
		locked.ferrugem_destroyed = true;r.flip_vehicle(locked)
	else:
		locked.taken = true
		if mode=="sewer":r.sewer.splash(impact,true)
		if locked.kind in ["bomb","air_bomb"]:r.mission_stats.bombs_broken = int(r.mission_stats.get("bombs_broken",0))+1
	r.events.append({"type":"ferrugem_fire","bird":"ferrugem","x":impact.x,"y":impact.y,"object":locked.kind})
	shots += 1;bird.attacks += 1;until_shot = interval(bird.level);locked = {};phase = "fire";age = 0
	return true

func advance(bird,r,dt: float) -> void:
	if dt<=0 or r.dead or r.leader_index()<0:return
	var current = run_mode(r)
	if current!=mode:
		cancel_charge();mode = current
	if mode=="transition":return
	until_shot = maxf(0,until_shot-dt)
	if phase=="idle":
		if until_shot>0:return
		locked = find_target(r)
		if locked.is_empty():return
		charge_seconds = clampf((front(locked,r)-80)/maxf(1,speed(locked,r)),.28,.72)
		phase = "charge";age = 0
		r.events.append({"type":"ferrugem_charge","bird":"ferrugem","x":bird.point.x,"y":bird.point.y})
		return
	age += dt
	if phase=="charge":
		if locked.is_empty() or not objects(r).has(locked) or not eligible(locked,r) or front(locked,r)<=40:
			cancel_charge();return
		aim = clampf((target_point(locked,r)-bird.point).angle(),-.28,.48)
		if age>=charge_seconds:
			if not fire(bird,r):cancel_charge()
	elif phase=="fire":
		impact.x -= (r.space.battle.scroll_speed(r)*.65 if mode=="space" else r.sewer.scroll_speed(r) if mode=="sewer" else r.speed)*dt
		if age>=.22:phase = "recover";age = 0
	elif phase=="recover" and age>=.46:phase = "idle";age = 0;aim = 0

func progress() -> float:return clampf(age/charge_seconds,0,1) if phase=="charge" else 1.0

func eye(bird) -> Vector2:return Art.laser_eye(bird.point,phase,age,progress(),aim)

func paint(g,bird) -> void:
	var c = g.paint_target
	if phase=="idle" or run_mode(g.runner)=="transition":
		Art.paint(c,"ferrugem",bird.point,68,bird.clock);return
	Art.paint_laser(c,bird.point,phase,age,progress(),aim)
	var origin = eye(bird)
	if phase=="charge":
		var t = progress();var glow = .22+t*.5
		c.draw_circle(origin,5+t*7,Color(MINT,glow*.28))
		c.draw_arc(origin,14-7*t,age*12,age*12+TAU*.8,20,Color(MINT,glow),1.7,true)
		for i in range(3):
			var direction = Vector2.from_angle(age*5+i*TAU/3)
			c.draw_line(origin+direction*(25-15*t),origin+direction*(20-14*t),Color(MINT,glow),1.5,true)
	elif phase=="fire" and age<.18:
		var opacity = 1-smoothstep(.04,.18,age)
		c.draw_line(origin,impact,Color(.25,.91,.86,.24*opacity),11,true)
		c.draw_line(origin,impact,Color(MINT,.9*opacity),4.5,true)
		c.draw_line(origin,impact,Color(1,1,.91,opacity),1.8,true)
		c.draw_circle(origin,7,Color(1,1,.91,opacity))
		c.draw_arc(impact,12+age*85,0,TAU,20,Color(MINT,opacity),2,true)
