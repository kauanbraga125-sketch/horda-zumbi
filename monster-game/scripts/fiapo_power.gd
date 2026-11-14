extends RefCounted
## One bonus passenger, created only after Fiapo is fully outside the camera.
## Reuses the blue civilian's existing idle/run/capture frames and Fiapo's atlas.
const Art = preload("res://scripts/bird_art.gd")
const HEIGHT = 96.0
const CIVIL_HEIGHT = 112.0
const COLLAR = Vector2(22,-51.5)
const EXIT_MARGIN = 160.0
const SEARCH_SECONDS = .48
const RETURN_SECONDS = 1.45
var phase = "idle"
var age = 0.0
var until_fetch = 28.0
var flight = Vector2.ZERO
var source = Vector2.ZERO
var face = 1.0
var lean = 0.0
var civil: Dictionary = {}
var picked = false
var suspended = false
var mode = ""
var deliveries = 0
var serial = 0
var announced = false
var trail: Array[Vector2] = []

static func interval(level: int) -> float:return 28.0-(clampi(level,1,3)-1)*4.0

func reset(level: int) -> void:
	phase = "idle";age = 0;until_fetch = interval(level);flight = Vector2.ZERO;source = Vector2.ZERO
	face = 1;lean = 0;civil.clear();picked = false;suspended = false;mode = "";deliveries = 0;serial = 0;announced = false;trail.clear()

func run_mode(r) -> String:
	if r.sky.active:return "transition"
	if r.space.active:return "space" if r.space.phase=="flight" else "transition"
	if r.sewer.active:return "sewer" if r.sewer.phase=="ride" else "transition"
	return "street"

func curve(from: Vector2,to: Vector2,t: float,bow: float) -> Vector2:
	return from.lerp(to,t)+Vector2(0,-sin(t*PI)*bow)

func next_phase(value: String) -> void:
	phase = value;age = 0;source = flight

func make_civil(point: Vector2) -> Dictionary:
	return {"id":-2000-serial,"kind":"civilian","variant":0,"x":point.x,"y":point.y,"base_y":point.y,"width":70.0,"taken":false,"state":"normal","group":-1,"rescued":true,"pose":"panic","civil_key":"civil_casaco_azul_nerd","civil_clip":"parado_nervoso","civil_time":0.0,"civil_flip":true,"civil_previous_flip":true,"civil_turn_left":0.0,"vx":0.0,"vy":0.0,"age":0.0,"bob":0.0,"speech_left":0.0,"speaker":false,"spoke":true,"bird_angle":0.0,"bird_bonus":true}

func outside_point(r) -> Vector2:
	var lead = r.members[r.leader_index()]
	return Vector2(r.view_right+EXIT_MARGIN,lead.y-250)

func begin_fetch(bird,r) -> bool:
	civil.clear();picked = false;announced = false;trail.clear()
	flight = bird.point;face = 1;lean = 0;next_phase("prepare");until_fetch = interval(bird.level)
	r.events.append({"type":"bird_fetch","bird":"fiapo","x":flight.x,"y":flight.y})
	return true

func grip() -> Vector2:return flight+Vector2(-4*face,HEIGHT*.35).rotated(lean)

func attach_civil() -> void:
	var swing = sin(age*8.5)*.11-lean*.65
	var foot = grip()-COLLAR.rotated(swing)
	civil.x = foot.x;civil.y = foot.y;civil.bird_angle = swing
	civil.civil_flip = face<0;civil.civil_previous_flip = civil.civil_flip
	civil.civil_clip = "corrida";civil.civil_time = .14+sin(age*5)*.035

func advance(bird,r,dt: float) -> void:
	if dt<=0 or r.dead or r.leader_index()<0:return
	var current = run_mode(r)
	if current=="transition" or r.transform_left>0:
		suspended = true;return
	if suspended or (not mode.is_empty() and current!=mode):
		# Keep an already grabbed passenger through covered course transitions.
		if picked and not civil.is_empty() and not civil.taken:
			flight = bird.point+Vector2(90,-75);next_phase("carry");civil.state = "bird"
		else:
			civil.clear();phase = "idle";until_fetch = maxf(until_fetch,2.0)
		trail.clear();suspended = false
	mode = current
	until_fetch = maxf(0,until_fetch-dt)
	if phase=="idle":
		if until_fetch<=0 and r.active_count()<r.MAX_HORDE:
			if not begin_fetch(bird,r):until_fetch = 2.0
		return
	age += dt
	if not civil.is_empty():civil.age = float(civil.get("age",0))+dt
	var lead = r.members[r.leader_index()]
	var home: Vector2 = bird.point
	var before = flight
	match phase:
		"prepare":
			flight = home+Vector2(-sin(age/.28*PI)*8,-smoothstep(0,.28,age)*13)
			if age>=.28:next_phase("outbound")
		"outbound":
			flight = curve(source,outside_point(r),smoothstep(0,.95,age),38)
			if age>=.95:
				flight = outside_point(r);trail.clear();next_phase("search")
		"search":
			flight = outside_point(r)
			if age>=SEARCH_SECONDS and flight.x-HEIGHT>r.view_right:
				# The bonus NPC never belongs to or replaces a course entity.
				serial += 1;civil = make_civil(Vector2.ZERO);civil.state = "bird";picked = true
				attach_civil();next_phase("carry")
				r.events.append({"type":"bird_fetch_grab","bird":"fiapo","x":flight.x,"y":flight.y})
		"carry":
			var delivery = Vector2(lead.x+10,lead.y-268)
			flight = curve(source,delivery,smoothstep(0,RETURN_SECONDS,age),28)
			if not announced and flight.x+HEIGHT*.5<r.view_right:
				announced = true;r.events.append({"type":"npc_voice","npc":"civilian","variant":0})
			if age>=RETURN_SECONDS:
				flight = delivery;attach_civil();civil.drop_vy = 25.0;next_phase("drop")
		"drop":
			flight = curve(source,home,smoothstep(0,.8,age),22)
			civil.bird_angle = move_toward(float(civil.bird_angle),0,dt*.65)
			civil.drop_vy += 980*dt;civil.y += float(civil.drop_vy)*dt
			civil.x = lerpf(float(civil.x),float(lead.x),1-exp(-dt*8))
			if civil.y>=lead.y-25:
				civil.bird_angle = 0;civil.state = "normal";r.begin_capture(civil,lead)
				civil.capture_offset = Vector2(15,-8);next_phase("capture")
		"capture":
			flight = flight.lerp(home,1-exp(-dt*6))
			var member = r.member_by_id(int(civil.capturer))
			if member.is_empty():
				civil.state = "normal";r.begin_capture(civil,lead);member = lead
			civil.x = member.x+civil.capture_offset.x;civil.y = member.y+civil.capture_offset.y
			civil.capture_left = maxf(0,float(civil.capture_left)-dt)
			if civil.capture_left<=0:
				r.complete_capture(civil,Vector2(member.x,member.y));deliveries += 1;next_phase("recover")
		"recover":
			flight = flight.lerp(home,1-exp(-dt*8))
			if age>=.42:civil.clear();phase = "idle";picked = false;trail.clear()
	var dx = flight.x-before.x
	var desired_face = -1.0 if dx<-.1 else 1.0 if dx>.1 else face
	face = move_toward(face,desired_face,dt*9)
	lean = move_toward(lean,clampf(dx/maxf(dt,.001)*.0004,-.19,.19),dt*1.8)
	if phase=="carry":attach_civil()
	trail.append(flight)
	if trail.size()>9:trail.pop_front()

func paint(g,bird) -> void:
	var r = g.runner;var c = g.paint_target
	if phase=="idle" or suspended or run_mode(r)=="transition" or r.transform_left>0:
		Art.paint(c,"fiapo",bird.point,68,bird.clock);return
	if phase=="search":return
	if not civil.is_empty() and not civil.taken:
		g.draw_civilian(civil)
	if phase in ["outbound","carry"] and trail.size()>2:
		c.draw_polyline(PackedVector2Array(trail),Color(.60,.88,.96,.10),2,true)
	var height = lerpf(68,HEIGHT,smoothstep(0,.28,age)) if phase=="prepare" else lerpf(HEIGHT,68,smoothstep(0,.42,age)) if phase=="recover" else HEIGHT
	Art.paint_carrier(c,flight,height,bird.clock,face,lean,phase=="drop" and age<.15,phase=="carry")
	if phase=="carry":
		var p = grip()
		c.draw_line(p+Vector2(-4,-4),p+Vector2(-1,2),Color("c9954c"),2,true)
		c.draw_line(p+Vector2(4,-3),p+Vector2(1,2),Color("c9954c"),2,true)
