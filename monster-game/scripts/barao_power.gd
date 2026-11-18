extends "res://scripts/bird_coin_flight.gd"

const Art = preload("res://scripts/bird_art.gd")
const INTERVAL = 25.0
const DOUBLE_TIME = 8.0
const DROP_TIME = 2.35
const GOLD_TIME = .72
const RELEASES = [.64,.78,.92,1.06,1.20,1.34]
const GOLD = Color("ffd16c")
const BRIGHT = Color("fff2be")
enum Power { NONE, DOUBLE, DROP, BOMBS }
const CAST_EVENTS = ["","barao_double","barao_trail","barao_bombs"]

var until_power = INTERVAL
var next_power = Power.DOUBLE
var active_power = Power.NONE
var power_age = 0.0
var bombs_ready = false
var released = 0
var converted: Array[Dictionary] = []

func reset() -> void:
	until_power = INTERVAL
	next_power = Power.DOUBLE
	active_power = Power.NONE
	power_age = 0
	bombs_ready = false
	released = 0
	mode = ""
	coins.clear()
	converted.clear()

func advance(bird,r,dt: float) -> void:
	if dt<=0 or r.dead or r.leader_index()<0:return
	var current = mode_of(r)
	if current!=mode:
		coins.clear()
		converted.clear()
		if active_power in [Power.DROP,Power.BOMBS]:active_power = Power.NONE
		mode = current
	if mode not in ["street","sewer","space"] or r.transform_left>0:return

	until_power = maxf(0,until_power-dt)
	if active_power!=Power.NONE:
		power_age += dt
		match active_power:
			Power.DOUBLE:
				if power_age>=DOUBLE_TIME:active_power = Power.NONE
			Power.DROP:
				while released<RELEASES.size() and power_age>=RELEASES[released]:
					drop_coin(bird,r,released)
					released += 1
				if power_age>=DROP_TIME:active_power = Power.NONE
			Power.BOMBS:
				if power_age>=GOLD_TIME:
					converted.clear()
					active_power = Power.NONE
	if active_power==Power.NONE and until_power<=0:
		var due = next_power
		next_power = Power.DOUBLE if due==Power.BOMBS else due+1
		until_power = INTERVAL
		if due==Power.BOMBS:bombs_ready = true
		else:cast(r,due)
	if active_power==Power.NONE and bombs_ready:
		transmute(r)
	advance_coins(r,dt)

func cast(r,power: int) -> void:
	active_power = power
	power_age = 0
	released = 0
	r.events.append({"type":CAST_EVENTS[power]})

func doubles_coins() -> bool:
	return active_power==Power.DOUBLE

func lead_x(r) -> float:
	if mode=="space":return r.space.x
	if mode=="sewer" and not r.sewer.boats.is_empty():return r.sewer.boats[0].x
	var leader = r.leader_index()
	return r.members[leader].x if leader>=0 else r.ANCHOR

func drop_pose(bird,r,age: float) -> Vector2:
	var travel = smoothstep(.05,.59,age)*(1-smoothstep(1.40,DROP_TIME,age))
	var forward = lerpf(220,390,smoothstep(.59,1.4,age))
	var goal = Vector2(minf(lead_x(r)+forward,r.view_right-68),maxf(92,bird.point.y-28))
	return bird.point.lerp(goal,travel)+Vector2(0,sin(age*12)*5*travel)

func drop_coin(bird,r,index: int) -> void:
	var tail = drop_pose(bird,r,RELEASES[index])+Vector2(-25,27)
	var floor_y = INF
	if mode=="sewer" and not r.sewer.boats.is_empty():floor_y = float(r.sewer.boats[0].y)-24
	elif mode=="space":floor_y = r.space.y-r.space.member_height(r)*.5
	launch_coin(tail,Vector2(-32-index*14,105+index*12),index*1.7,floor_y)
	if index%2==0:r.events.append({"type":"barao_drop"})

func bomb_point(r,e: Dictionary) -> Vector2:
	if mode=="sewer":
		return r.sewer.object_surface(e)-Vector2(0,79 if e.kind=="rotor" else 42)
	return Vector2(e.x,e.y if e.kind=="air_bomb" else e.y-HordeTuning.BOMB_HEIGHT*.5)

func transmute(r) -> void:
	if mode=="space":return
	var sewer = mode=="sewer"
	var hazards = r.sewer.objects if sewer else r.entities
	var kinds = ["barrel","rotor"] if sewer else ["bomb","air_bomb"]
	var origin = lead_x(r)
	for e in hazards:
		if coins.size()>=MAX_COINS:break
		if e.kind not in kinds or e.taken or e.state!="normal" or e.x<origin+90 or e.x>r.view_right-48:continue
		if e.get("damaged",false):continue
		var point = bomb_point(r,e)
		var speed = r.sewer.scroll_speed(r) if sewer else r.speed-float(e.vx)
		var water_lane = float(r.sewer.boats[0].y)-24 if sewer and not r.sewer.boats.is_empty() else INF
		e.taken = true
		r.mission_stats.bombs_broken = int(r.mission_stats.get("bombs_broken",0))+1
		converted.append({"hazard":e,"point":point,"speed":speed})
		launch_coin(point,Vector2(-speed*.78,-125),point.x*.01,water_lane)
	if converted.is_empty():return
	bombs_ready = false
	cast(r,Power.BOMBS)

func paint(g,bird) -> void:
	var c = g.paint_target
	var p: Vector2 = bird.point
	var r = g.runner
	match active_power:
		Power.DOUBLE:
			if power_age<1.25:Art.paint_barao(c,p,clampi(int(power_age*16),0,19),0)
			else:Art.paint(c,"barao",p,82,bird.clock)
			g.text("×2",p+Vector2(0,-48),23,GOLD,true,true,3)
		Power.DROP:
			p = drop_pose(bird,r,power_age)
			var kick = 0.0
			for release in RELEASES:
				kick += sin(clampf((power_age-release)/.15,0,1)*PI)
			Art.paint_barao(c,p+Vector2(kick*6,-kick*4),[0,1,4,1][posmod(int(power_age*18),4)],kick*.22-.08)
			for release in RELEASES:
				var t = (power_age-release)/.28
				if t>=0 and t<1:
					var tail = drop_pose(bird,r,release)+Vector2(-25-32*t,27+12*t)
					paint_burst(c,tail,t,18,4)
		Power.BOMBS:
			for item in converted:paint_conversion(g,p,item)
			Art.paint_barao(c,p,clampi(int(power_age*18)+4,4,15),-.09*sin(power_age/GOLD_TIME*PI))
		_:
			Art.paint(c,"barao",p,82,bird.clock,"hurt" if bird.emotion_left>.65 else "")
	paint_coins(g)

func paint_conversion(g,bird_point: Vector2,item: Dictionary) -> void:
	var c = g.paint_target
	var t = clampf(power_age/GOLD_TIME,0,1)
	var e: Dictionary = item.hazard
	var point: Vector2 = item.point-Vector2(item.speed*power_age,0)
	var ray = 1-smoothstep(.12,.63,t)
	if ray>0:
		var source = bird_point+Vector2(14,-5)
		var crest = (source+point)*.5+Vector2(0,-54)
		var trail = PackedVector2Array()
		for i in range(13):
			var u = i/12.0
			trail.append(source.lerp(crest,u).lerp(crest.lerp(point,u),u))
		c.draw_polyline(trail,Color(GOLD,.22*ray),11,true)
		c.draw_polyline(trail,Color(BRIGHT,.9*ray),3,true)
	var dissolve = 1-smoothstep(.06,.42,t)
	if dissolve>0 and mode=="street":
		var aerial = e.kind=="air_bomb"
		var tex: Texture2D = g.art.ritual[3] if aerial else g.art.props[0]
		var height = 85.8 if aerial else HordeTuning.BOMB_HEIGHT
		g.scenery.sprite(c,tex,point,height*(.65+.35*dissolve),Color(1,.80,.42,dissolve),t*.4)
	paint_burst(c,point,t,61,9)

func paint_burst(c,point: Vector2,t: float,span: float,count: int) -> void:
	var opacity = 1-t
	var radius = 5+span*smoothstep(0,1,t)
	c.draw_arc(point,radius,0,TAU,20,Color(GOLD,.68*opacity),2,true)
	for i in range(count):
		var angle = i*TAU/count+t*.42
		var p = point+Vector2.from_angle(angle)*radius*(.62+float(i%3)*.16)
		var size = (5+float(i%3))*opacity
		c.draw_line(p-Vector2(size,0),p+Vector2(size,0),Color(GOLD,opacity),2,true)
		c.draw_line(p-Vector2(0,size),p+Vector2(0,size),Color(BRIGHT,opacity),2,true)
