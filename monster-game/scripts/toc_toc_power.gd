extends RefCounted

const Art = preload("res://scripts/toc_toc_art.gd")
const BOMBS = ["bomb","air_bomb"]
const BOMB_CHANCE = .20
const VEHICLE_CHANCE = .02
const SEED_SALT = 0x746f63
const WINDUP = 5.0/Art.FPS
const CONTACT = 8.0/Art.FPS
const PECK_END = 16.0/Art.FPS
const HIT_BANK = .17
const RETURN_SECONDS = .62
const WINDUP_OFFSET = Vector2(116,49)
const SAFETY_LEAD = 78.0
var random = RandomNumberGenerator.new()
var seeded = false
var target: Dictionary = {}
var phase = "idle"
var result = ""
var age = 0.0
var approach_seconds = 0.0
var wake_left = 0.0
var search_left = 0.0
var position = Vector2.ZERO
var launch_from = Vector2.ZERO
var recoil_from = Vector2.ZERO
var bank = 0.0

func reset() -> void:
	cancel()
	seeded = false
	search_left = 0

func cancel() -> void:
	target = {}
	phase = "idle"
	result = ""
	age = 0

func on_street(r) -> bool:
	return not (r.sky.active or r.space.active or r.sewer.active) and r.transform_left<=0

func is_vehicle(entity: Dictionary) -> bool:
	return MonsterCatalog.VEHICLES.has(entity.kind)

func target_center(entity: Dictionary) -> Vector2:
	var height = float(entity.height) if is_vehicle(entity) else HordeTuning.BOMB_HEIGHT
	return Vector2(entity.x,entity.y if entity.kind=="air_bomb" else entity.y-height*.5)

func strike_point(entity: Dictionary) -> Vector2:
	var offset = Vector2(float(entity.width)*.36,float(entity.height)*.17) if is_vehicle(entity) else Vector2(29,11)
	return target_center(entity)-offset

func lead_distance(entity: Dictionary,lead_x: float) -> float:
	return float(entity.x)-float(entity.width)*.5-lead_x

func transit_time(from: Vector2,entity: Dictionary) -> float:
	return clampf(from.distance_to(strike_point(entity)-WINDUP_OFFSET)/1200.0,.25,.46)

func find_target(r,from: Vector2,lead_x: float) -> Dictionary:
	var best = {}
	var best_distance = 850.0
	for entity in r.entities:
		if entity.taken or entity.state!="normal" or entity.has("toc_toc_attempted"):continue
		if not is_vehicle(entity) and entity.kind not in BOMBS:continue
		if entity.x>r.view_right-38:continue
		var lead = lead_distance(entity,lead_x)
		var closing_speed = maxf(0,r.speed-minf(float(entity.vx),float(entity.get("rush_speed",entity.vx))))
		var needed = SAFETY_LEAD+closing_speed*(transit_time(from,entity)+CONTACT)+24
		if lead>=needed and lead<best_distance:
			best_distance = lead
			best = entity
	return best

func target_is_live(r,lead_x: float) -> bool:
	return not target.taken and target.state=="normal" and r.entities.has(target) and lead_distance(target,lead_x)>SAFETY_LEAD

func begin(bird,r,entity: Dictionary) -> void:
	target = entity
	target.toc_toc_attempted = true
	launch_from = bird.point+Vector2(0,Art.flight_bob(bird.clock))
	position = launch_from
	bank = Art.flight_bank(bird.clock)
	approach_seconds = transit_time(position,target)
	phase = "approach"
	age = 0
	wake_left = 0
	r.events.append({"type":"toc_toc_dash","x":position.x,"y":position.y})

func resolve(bird,r,hit: Vector2) -> void:
	var vehicle = is_vehicle(target)
	var won = random.randf()<(VEHICLE_CHANCE if vehicle else BOMB_CHANCE)
	result = ("vehicle" if vehicle else "bomb") if won else "miss"
	r.events.append({"type":"toc_toc_peck","x":hit.x,"y":hit.y,"result":result,"center":target_center(target)})
	bird.attacks += 1
	if result=="vehicle":
		r.flip_vehicle(target)
	elif result=="bomb":
		target.taken = true
		r.mission_stats.bombs_broken = int(r.mission_stats.get("bombs_broken",0))+1
	else:
		target.toc_toc_hit_at = r.elapsed
	target = {}
	recoil_from = position

func emit_wake(r,previous: Vector2,dt: float) -> void:
	wake_left -= dt
	if wake_left>0 or position.distance_squared_to(previous)<5:return
	wake_left = .038
	var heading = previous.direction_to(position)
	var tail = position-heading*34
	r.events.append({"type":"toc_toc_wake","x":tail.x,"y":tail.y,"direction":heading})

func advance(bird,r,dt: float) -> void:
	if not on_street(r):
		cancel()
		return
	var leader = r.leader_index()
	if leader<0:return
	if not seeded:
		random.seed = r.run_seed ^ SEED_SALT
		seeded = true
	var lead_x = maxf(r.ANCHOR,float(r.members[leader].x))
	if phase=="idle":
		search_left -= dt
		if search_left>0:return
		search_left = .08
		var next = find_target(r,bird.point,lead_x)
		if not next.is_empty():begin(bird,r,next)
		return
	age += dt
	if not target.is_empty() and not target_is_live(r,lead_x):
		target = {}
		start_return()
		return
	if phase=="approach":
		var previous = position
		var t = clampf(age/approach_seconds,0,1)
		var ease = smoothstep(0,1,t)
		position = launch_from.lerp(strike_point(target)-WINDUP_OFFSET,ease)
		position.y -= sin(t*PI)*34
		bank = lerpf(Art.flight_bank(bird.clock),-.16,ease)+sin(t*PI)*.29
		emit_wake(r,previous,dt)
		if t>=1:
			phase = "peck"
			age = 0
	elif phase=="peck":
		if result.is_empty():
			var previous = position
			var hit = strike_point(target)
			var wind = sin(clampf(age/WINDUP,0,1)*PI*.5)
			var lunge = smoothstep(WINDUP,CONTACT,age)
			bank = lerpf(-.16-.08*wind,HIT_BANK,lunge)
			position = (hit-WINDUP_OFFSET-Vector2(13,4)*wind).lerp(hit-Art.peck_tip(HIT_BANK),lunge)
			if age>=WINDUP:emit_wake(r,previous,dt)
			if age>=CONTACT:resolve(bird,r,hit)
		else:
			var t = clampf((age-CONTACT)/(PECK_END-CONTACT),0,1)
			var bounce = sin(t*PI*.65)
			position = recoil_from+Vector2(-52 if result=="miss" else -33,-52)*bounce
			bank = lerpf(HIT_BANK,-.21,smoothstep(0,.6,t))
			if age>=PECK_END:start_return()
	elif phase=="return":
		var t = clampf(age/RETURN_SECONDS,0,1)
		var home = bird.point+Vector2(0,Art.flight_bob(bird.clock))
		position = recoil_from.lerp(home,smoothstep(0,1,t))
		position.y -= sin(t*PI)*(42 if result=="miss" else 64)
		var wobble = sin(t*TAU*3)*.14*(1-t) if result=="miss" else 0.0
		bank = lerpf(-.21,Art.flight_bank(bird.clock),smoothstep(0,.75,t))+wobble
		if t>=1:cancel()

func start_return() -> void:
	recoil_from = position
	phase = "return"
	age = 0

func paint(g,bird) -> void:
	var c = g.paint_target
	if phase=="idle" or not on_street(g.runner):
		Art.paint_flight(c,bird.point,Art.SIZE,bird.clock)
	elif phase=="peck":
		Art.paint(c,Art.PECK,mini(15,floori(age*Art.FPS)),position,Art.SIZE,bank)
	elif phase=="return" and result=="miss" and age<Art.MISS.size()/Art.FPS:
		Art.paint(c,Art.REACTION,Art.MISS[floori(age*Art.FPS)],position,Art.SIZE,bank)
	elif phase=="return" and result in ["vehicle","bomb"] and age<.4:
		Art.paint(c,Art.REACTION,8+floori(age*20),position,Art.SIZE,bank)
	else:
		Art.paint(c,Art.FLIGHT,Art.flight_frame(bird.clock),position,Art.SIZE,bank)
